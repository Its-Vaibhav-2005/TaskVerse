function localDay(now) {
  return `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
}

// Poll wall-clock time instead of chaining timers, so sleep/resume and edits take effect.
class HabitReminders {
  constructor(manager, {notify, onError = console.error} = {}) {
    this.manager = manager;
    this.notify = notify;
    this.onError = onError;
  }
  tick(now = new Date()) {
    const day = localDay(now), minute = now.getHours()*60 + now.getMinutes();
    for (const profile of this.manager.list()) {
      try {
        const db = this.manager.store(profile.id);
        const old = db.getPreference('reminderDelivery', {});
        const sent = old.day === day ? {...old.sent} : {};
        let changed = old.day !== day;
        for (const habit of db.load()) {
          const reminder = habit.reminder;
          if (!reminder?.enabled || habit.checks.includes(day) || habit.created > day ||
              !habit.weekdays.includes(now.getDay() || 7) ||
              habit.months && !habit.months.includes(day.slice(0,7)+'-01')) continue;
          const [hour, min] = reminder.time.split(':').map(Number);
          const start = hour*60 + min;
          if (minute < start) continue;
          const slot = Math.floor((minute-start)/reminder.interval);
          const key = `${habit.id}|${reminder.time}|${reminder.interval}`;
          // Only one current reminder after resume; never replay missed intervals.
          if (sent[key] >= slot) continue;
          const count = habit.dailyCounts[day] || 0;
          if (count >= habit.dailyTarget) continue;
          if (this.notify({workspaceId: profile.id, habitId: habit.id, title: habit.name,
            body: `${count}/${habit.dailyTarget} today · ${habit.dailyTarget-count} more to go. ${profile.alias}`}) !== false) {
            sent[key] = slot;
            changed = true;
          }
        }
        if (changed) db.setPreference('reminderDelivery', {day, sent});
      } catch (error) { this.onError(error); }
    }
  }
  start() {
    this.stop();
    this.tick();
    this.timer = setInterval(() => this.tick(), 15000);
    this.timer.unref?.();
  }
  stop() { clearInterval(this.timer); }
}
module.exports = {HabitReminders, localDay};

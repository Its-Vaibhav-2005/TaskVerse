'use strict';
const counter = document.getElementById('demo-count');
const add = document.getElementById('demo-add');
const detail = document.getElementById('demo-detail');
const reset = document.getElementById('demo-reset');
if (counter && add && detail && reset) {
  let count = 3;
  const render = () => {
    const complete = count >= 4;
    counter.textContent = complete ? '✓' : `${count}/4`;
    counter.setAttribute('aria-label', complete ? 'Daily target complete: 4 of 4' : `${count} of 4 completed`);
    counter.classList.toggle('complete', complete);
    detail.textContent = complete ? 'Daily target complete. Nicely done.' : 'One more small step.';
    add.disabled = complete;
  };
  add.addEventListener('click', () => { count = Math.min(4, count + 1); render(); });
  reset.addEventListener('click', () => { count = 3; render(); });
}

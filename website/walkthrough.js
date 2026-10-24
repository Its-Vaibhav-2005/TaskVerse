'use strict';

const productDemo = document.getElementById('product-demo');
document.querySelectorAll('[data-video-time]').forEach(button => {
  button.addEventListener('click', () => {
    const playChapter = () => {
      productDemo.currentTime = Number(button.dataset.videoTime);
      productDemo.play().catch(() => {
        // Keep native controls available if the browser requires another play gesture.
        productDemo.focus();
      });
    };
    if (productDemo.readyState >= 1) {
      playChapter();
    } else {
      productDemo.addEventListener('loadedmetadata', playChapter, { once: true });
      productDemo.preload = 'metadata';
      productDemo.load();
    }
  });
});

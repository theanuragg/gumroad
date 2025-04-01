export const delay = (function () {
  let timer: number | null = null;
  return function (callback: () => void, ms: number) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(callback, ms);
  };
})();

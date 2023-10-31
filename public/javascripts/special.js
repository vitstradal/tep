
jQuery(document).ready(function($) {
  var special_page = $('body').data('special-page') || 'none';
  if( special_page == 'pb2019' ) {
    $('body').addClass('pb2019');
    $('#sidebar-collapse').click();
    $('a.navbar-brand img').attr('src', '/setkani/pikobrani2019/pb2019-logo.png');
    $('#nav-search-input').attr('placeholder', 'už nehledej ... ');
    $('link[type="image/x-icon"]').attr('href', '/setkani/pikobrani2019/pikomat.png');
    $('span.input-icon i.ace-icon').removeClass('nav-search-icon');
  }
  if( special_page == 'ps22srp' ) {
    $('body').addClass('ps22srp');
    $('#sidebar-collapse').click();
    $('a.navbar-brand img').attr('src', '/setkani/pikobrani2019/pb2019-logo.png');
    $('#nav-search-input').attr('placeholder', 'už nehledej ... ');
    $('link[type="image/x-icon"]').attr('href', '/setkani/pikobrani2019/pikomat.png');
    $('span.input-icon i.ace-icon').removeClass('nav-search-icon');
  }
  if( special_page == 'pb2022' ) {
    pb2022_main();
  }
  if( special_page == 'pb2023' ) {
    $('body').addClass('pb2023');
    $('.sidebar').addClass('menu-min h-sidebar hide');
  }
})




const minBubbles = 30;
const maxBubbles = minBubbles * 2;
const minSize = 10;
const maxSize = 28;
const minDelay = 10;
const maxDelay = 28;
const minPos = 0;
const maxPos = 100;
const minBlur = 0;
const maxBlur = 3;

const $bubbles = document.querySelector('[class="pb22-bubbles"]');
const totalBubbles = getRandomIntInclusive(minBubbles, maxBubbles);
const bubbleElements = Array(totalBubbles).fill(null).map(() => {
  const bubbleSize = getRandomIntInclusive(minSize, maxSize);
  const bubblePos = getRandomIntInclusive(minPos, maxPos);
  const blurSize = getRandomIntInclusive(minBlur, maxBlur);
  const animationDelay = getRandomIntInclusive(minDelay, maxDelay);
  const $container = document.createElement('div');
  $container.className = 'bubble-container';
  $container.style.left = `${bubblePos}%`;
  $container.style.filter = `blur(${blurSize}px)`;
  $container.style.animationDuration = `${animationDelay}s`;
  const $bubble = document.createElement('div');
  $bubble.className = 'pb22-bubble';
  $bubble.style.width = `${bubbleSize}px`;
  $bubble.style.height = `${bubbleSize}px`;
  $container.appendChild($bubble);
  $bubbles.appendChild($container);
  return {
    $container: $container,
    $bubble: $bubble
  };
});

let ready = true;
let mouseX = 0;
let mouseY = 0;
const minDistanceMult = 2;
const maxDistanceMult = 4;

function getRandomIntInclusive(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pb22_calcDistance(x, y) {
  return Math.sqrt(x * x + y * y);
}


function pb22_updateElement(elem) {
  const width = parseInt(elem.$bubble.style.width, 10);
  const css = getComputedStyle(elem.$container);
  const computedWidth = parseInt(css.width, 10);
  const x = mouseX - (elem.$container.offsetLeft + computedWidth / 2);
  const y = mouseY - (elem.$container.offsetTop + parseInt(css.height, 10) / 2);
  const distance = pb22_calcDistance(x, y);
  if (distance <= computedWidth) {
    elem.$bubble.classList.add('bubbleHover');
    elem.$bubble.classList.remove('minDistance');
    elem.$bubble.classList.remove('maxDistance');
  } else {
    elem.$bubble.classList.remove('bubbleHover');
    if (distance <= width * minDistanceMult) {
      elem.$bubble.classList.add('minDistance');
      elem.$bubble.classList.remove('maxDistance');
    } else if (distance <= width * maxDistanceMult) {
      elem.$bubble.classList.remove('minDistance');
      elem.$bubble.classList.add('maxDistance');
    } else {
      elem.$bubble.classList.remove('minDistance');
      elem.$bubble.classList.remove('maxDistance');
    }
  }
}

function pb22_update() {
  if (ready) {
    ready = false;
    bubbleElements.forEach(pb22_updateElement);
    ready = true;
  }
}

function pb2022_main() {
  document.addEventListener('mousemove', e => {
    mouseX = e.pageX;
    mouseY = e.pageY;
  }, false);

  const interval = 100;
  let intervalId = document.hasFocus() && setInterval(pb22_update, interval);
  document.addEventListener('mouseenter', () => {
    if (!intervalId) {
      pb22_update();
      intervalId = setInterval(pb22_update, interval);
    }
  }, false);
  document.addEventListener('mouseleave', () => {
    ready = false;
    intervalId = clearInterval(intervalId);
    bubbleElements.forEach(elem => elem.$bubble.className = 'pb22-bubble');
    ready = true;
  }, false);

}

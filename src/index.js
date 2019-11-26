/* globals alert */
const weexPluginVSlider = {
  show () {
    alert('Module weexPluginVSlider is created sucessfully ');
  }
};

const meta = {
  weexPluginVSlider: [{
    lowerCamelCaseName: 'show',
    args: []
  }]
};

function init (weex) {
  weex.registerModule('weexPluginVSlider', weexPluginVSlider, meta);
}

export default {
  init: init
};

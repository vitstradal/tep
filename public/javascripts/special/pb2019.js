
jQuery(document).ready(function($) {
        var bgimg = $('body').data('background-image');
        if( bgimg ) {
          if( bgimg == 'pb2019' || bgimg == 'ps22srp') {
            $('body').addClass('pb2019');
            if( bgimg == 'ps22srp') {
              $('body').addClass('ps22srp');
            }
            $('#sidebar-collapse').click();
            $('a.navbar-brand img').attr('src', '/setkani/pikobrani2019/pb2019-logo.png');
            $('#nav-search-input').attr('placeholder', 'už nehledej ... ');
            $('link[type="image/x-icon"]').attr('href', '/setkani/pikobrani2019/pikomat.png');
            $('span.input-icon i.ace-icon').removeClass('nav-search-icon');
          }
        }
})

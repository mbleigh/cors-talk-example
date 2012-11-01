if (window.location.toString().indexOf("herokuapp") >= 0) {
  window.AUTH_HOST = "http://cors-talk-example-auth.herokuapp.com"
  window.STREAM_HOST = "http://cors-talk-example-stream.herokuapp.com"
} else {
  window.AUTH_HOST = "http://localhost:3001"
  window.STREAM_HOST = "http://localhost:3002"
}


$.ajaxPrefilter(function(options) {
  if (localStorage['token']) {
    options.headers = options.headers || {};
    options.headers["Authorization"] = "Bearer " + localStorage["token"];
  }
});

window.app = {
  launch: function() {
    if (window.location.hash.indexOf("#token=") == 0) {
      app.verifyToken(window.location.hash.replace("#token=",""));
    } else {
      if (localStorage["token"]) {
        $("body").addClass('signed-in')
        app.fetchStream()
      }
    }
  },

  logout: function() {
    localStorage.clear();
    window.location.reload();
  },

  verifyToken: function(token) {
    window.location.hash = "#/";
    localStorage["token"] = token

    $.ajax({
      url: AUTH_HOST + '/verify',
      type: "GET",
      dataType: "json",
      success: function(data) {
        localStorage["user"] = JSON.stringify(data)
        app.launch();
      },
      error: function() {
        localStorage.clear();
        $("#content").html("<p class='lead text-error'>There was a problem verifying your token. <a href='" + AUTH_HOST + "'>Sign in Again</a></p>");
      }
    });
  },

  renderActivity: function(activity) {
    return "<div class='well well-small activity'><span class='message'>" + activity.activity + "</span><span class='time pull-right muted'>" + new Date(activity.created_at * 1000) + "</span></div>";
  },

  fetchStream: function(options) {
    $.ajax({
      url: STREAM_HOST + "/activities",
      type: "GET",
      dataType: "json",
      success: function(data) {
        $("#activities").html("");
        $.each(data, function() {
          $("#activities").append(app.renderActivity(this));
        });
      },
      error: app.logout
    }); 
  },

  postActivity: function(e) {
    e.preventDefault();
    $.ajax({
      url: STREAM_HOST +"/activities",
      type: "POST",
      dataType: "json",
      data: {activity: $("#activity-form [name=activity]").val()},
      success: function(data) {
        $("#activity-form :input").val("");
        $("#activities").prepend(app.renderActivity(data));
      }
    });
  }
}

$("#sign-in").attr("href", AUTH_HOST);
$("#activity-form").on("submit", app.postActivity);
app.launch();
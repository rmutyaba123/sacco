<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="utf-8"/>

	<title>Login Test</title>
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta content="width=device-width, initial-scale=1.0" name="viewport"/>
	<meta http-equiv="Content-type" content="text/html; charset=utf-8">
	<meta content="" name="description"/>
	<meta content="" name="author"/>

	<link rel="shortcut icon" href="./assets/logos/favicon.png"/>
</head>

<body class="page-md login" id="login">
	<!-- BEGIN LOGIN FORM -->
	<form class="login-form" method="POST" action="j_security_check" method="post">
		<h3 class="form-title">Login</h3>
		<div class="alert alert-danger display-hide">
			<span>Enter  username and password. </span>
		</div>
		<div class="form-group">
			<!--ie8, ie9 does not support html5 placeholder, so we just show field title for that-->
			<label class="control-label visible-ie8 visible-ie9">Username</label>
			<div class="input-icon">
				<i class="fa fa-user"></i>
				<input class="form-control placeholder-no-fix" type="text" autocomplete="off" placeholder="Username" 
				id="j_username" name="j_username" autofocus required/>
			</div>
		</div>
		<div class="form-group">
			<label class="control-label visible-ie8 visible-ie9">Password</label>
			<div class="input-icon">
				<i class="fa fa-lock"></i>
				<input class="form-control placeholder-no-fix" type="password" autocomplete="off" placeholder="Password" 
				id="j_password" name="j_password" required/>
			</div>
		</div>
		<div class="form-actions">
			<button type="submit" >Login</button>
			<button type="button" id="login" >Ajax Login</button>
		</div>
	</form>

<script src="./assets/global/plugins/jquery.min.js" type="text/javascript"></script>
<script>
	
	$('#login').click(function(){
		var username = $("#j_username").val();
		var password = $("#j_password").val();
        
        $.post("ajaxauth", {j_username:username, j_password:password}, function(data) {
            console.log('AJAX Auth');
			console.log(data);
        }, "JSON");
	});
	
</script>

</body>

</html>

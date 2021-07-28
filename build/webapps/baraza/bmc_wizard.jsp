<!DOCTYPE html>
<html lang="en" >

<%@ page import="org.baraza.web.BWebData" %>
<% 

	String dbConfig = "java:/comp/env/jdbc/database";
	BWebData webData = new BWebData(dbConfig, request);

    if(request.getParameter("data") != null) {
        session.setAttribute("bmcId", request.getParameter("data"));
    }

%>
    <!-- begin::Head -->
    <head>
        <meta charset="utf-8" />
        
        <title>BMC Wizard</title>
        <meta name="description" content="Form wizard examples"> 
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, shrink-to-fit=no">

        <!--begin::Web font -->
        <script src="https://ajax.googleapis.com/ajax/libs/webfont/1.6.16/webfont.js"></script>
        <script>
          WebFont.load({
            google: {"families":["Poppins:300,400,500,600,700","Roboto:300,400,500,600,700"]},
            active: function() {
                sessionStorage.fonts = true;
            }
          });
        </script>
        <!--end::Web font -->

		<!--begin::Global Theme Styles -->
		    <link href="assets/canvas/vendor/vendors.bundle.css" rel="stylesheet" type="text/css" />
		    <link href="assets/canvas/vendor/style.bundle.css" rel="stylesheet" type="text/css" />
		<!--end::Global Theme Styles -->

		<!-- App favicon -->
    	<link rel="shortcut icon" href="assets/canvas/images/favicon.png">

    	<!-- Bootstrap Css -->
	    <link href="assets/canvas/css/bootstrap.min.css" id="bootstrap-style" rel="stylesheet" type="text/css" />
	    <!-- Icons Css -->
	    <link href="assets/canvas/css/icons.min.css" rel="stylesheet" type="text/css" />
	    <!-- App Css-->
	    <link href="assets/canvas/css/app.min.css" id="app-style" rel="stylesheet" type="text/css" />
	    <link href="assets/canvas/css/custom.css" id="app-style" rel="stylesheet" type="text/css" />
    </head>
    <!-- end::Head -->

    
<!-- begin::Body -->
<body data-sidebar="dark" class="m-page--fluid m-header--fixed m-header--fixed-mobile">
        
        
<!-- begin:: Page -->
<div class="m-grid m-grid--hor m-grid--root m-page">

<!-- BEGIN: Header -->
<div id="m_header" class="m-grid__item    m-header "  m-minimize-offset="200" m-minimize-mobile-offset="200" >
	
    <%@ include file="./assets/include/canvas_header.jsp" %>

</div>
<!-- End: Header -->

	
<!-- begin::Body -->
<div class="m-grid__item m-grid__item--fluid m-wrapper container-fluid page-content">
			    			    
	        
<div class="m-content">

<!-- start page title -->
<div class="row">
    <div class="col-12">
        <div class="page-title-box d-flex align-items-center justify-content-between">
            <h4 class="mb-0 font-size-18">BMC Set-up Wizard</h4>

            <div class="page-title-right">
                <ol class="breadcrumb m-0">
                    <li class="breadcrumb-item"><a href="javascript: void(0);">Tasks</a></li>
                    <li class="breadcrumb-item active">BMC Wizard</li>
                </ol>
            </div>

        </div>
    </div>
</div>
<!-- end page title -->

<!--Begin::Main Portlet-->
<div class="m-portlet m-portlet--full-height">

	<!--begin: Portlet Body-->
	<div class="m-portlet__body m-portlet__body--no-padding">

		<!--begin: Form Wizard-->
		<div class="m-wizard m-wizard--3 m-wizard--success" id="m_wizard">

			<!--begin: Message container -->
		    <div class="m-portlet__padding-x">
		        <!-- Here you can put a message or alert -->
		    </div>
		    <!--end: Message container -->

			<div class="row m-row--no-padding">
				<div class="col-xl-3 col-lg-12 right-steps">
					<!--begin: Form Wizard Head -->
					<div class="m-wizard__head">

						<!--begin: Form Wizard Progress -->  		
						<div class="m-wizard__progress">	
							<div class="progress">		 
								<div class="progress-bar"  role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100"></div>						 	
							</div>			 
						</div> 
			            <!--end: Form Wizard Progress --> 

			            <!--begin: Form Wizard Nav -->
						<div class="m-wizard__nav">
							<div class="m-wizard__steps">
								<div class="m-wizard__step" m-wizard-target="m_wizard_form_step_1">
									<div class="m-wizard__step-info">
										<a href="#" class="m-wizard__step-number">							 
											<span><span>1</span></span>							 
										</a>
										<div class="m-wizard__step-line">
											<span></span>
										</div>
										<div class="m-wizard__step-label steps">
											Getting Started
										</div>
									</div>
								</div>
								<%= webData.getBmcWizardHeader() %>
							</div>
						</div>	
						<!--end: Form Wizard Nav -->
					</div>
					<!--end: Form Wizard Head -->	
				</div>
				<div class="col-xl-9 col-lg-12">
					<!--begin: Form Wizard Form-->
					<div class="m-wizard__form">
						<!--
							1) Use m-form--label-align-left class to alight the form input lables to the right
							2) Use m-form--state class to highlight input control borders on form validation
						-->
						<form class="m-form m-form--label-align-left- m-form--state-" id="m_form">
							<!--begin: Form Body -->
							<div class="m-portlet__body m-portlet__body--no-padding">
								<!--begin: Form Wizard Step 1-->
								<div class="m-wizard__form-step m-wizard__form-step--current" id="m_wizard_form_step_1">
									<div class="m-form__section m-form__section--first">
										<div class="m-form__heading">
											<h3 class="m-form__heading-title">Getting Started</h3>
										</div>
										<label class="col-form-label">What is a Business Model Canvas?</label>
										<div class="form-group m-form__group m--margin-bottom-100">
											<p class="description">This is a strategic management tool for developing new or documenting existing business model.</p>
				                            <p class="description"> The idea is to single out the crucial components of a company that are required to make money.</p>
				                            <p class="description">You get Nine Sections on the canvas to fill in with relevant data.</p>
				                            <p class="description">Click <span class="text-dark">'Continue'</span> to get started.</p>
			                        	</div>
									</div>
								</div>
								<!--end: Form Wizard Step 1-->

								<%= webData.getBmcWizard() %>
								
							</div>
							<!--end: Form Body -->
							<!--begin: Form Actions -->
							<div class="m-portlet__foot m-portlet__foot--fit m--margin-top-20">
								<div class="m-form__actions">
									<div class="row">
										<div class="col-lg-6 m--align-left">
											<a href="#" class="btn btn-secondary m-btn m-btn--custom m-btn--icon border-secondary" data-wizard-action="prev">
											<span>
											<i class="la la-arrow-left"></i>&nbsp;&nbsp;
											<span class="text-dark">Back</span>
											</span>
											</a>
										</div>
										<div class="col-lg-6 m--align-center">
											<a href="#" class="btn btn-success m-btn m-btn--custom m-btn--icon saveBMC" data-wizard-action="submit">
											<span>
											<i class="la la-check"></i>&nbsp;&nbsp;
											<span>Save and Finish</span>
											</span>
											</a>
											<a href="#" class="btn btn-success m-btn m-btn--custom m-btn--icon updateBMC" data-wizard-action="next">
											<span>
											<span>Continue</span>&nbsp;&nbsp;
											<i class="la la-arrow-right"></i>
											</span>
											</a>
										</div>
									</div>
								</div>
							</div>
							<!--end: Form Actions -->
						</form>
					</div>
					<!--end: Form Wizard Form-->

				</div>
			</div>
		</div>
		<!--end: Form Wizard-->

	</div>
	<!--end: Portlet Body-->
</div>
<!--End::Main Portlet--> 
    	 

</div>
</div>
<!-- end:: Body -->

				
<!-- begin::Footer -->
<div class="m-container m-container--fluid m-container--full-height m-page__container">
	
    <%@ include file="./assets/include/canvas_footer.jsp" %>

</div>
<!-- end::Footer -->		
		

</div>
<!-- end:: Page -->

	    
<!-- begin::Scroll Top -->
<div id="m_scroll_top" class="m-scroll-top">
	<i class="la la-arrow-up"></i>
</div>
<!-- end::Scroll Top -->		    


<!--begin::Global Theme Bundle -->
<script src="assets/canvas/vendor/vendors.bundle.js" type="text/javascript"></script>
<script src="assets/canvas/vendor/scripts.bundle.js" type="text/javascript"></script>
<script src="assets/canvas/libs/metismenu/metisMenu.min.js"></script>
<script src="assets/canvas/libs/node-waves/waves.min.js"></script>
<script src="assets/canvas/js/app-full.js"></script>
<!--end::Global Theme Bundle -->


<!--begin::Page Scripts -->
<script src="assets/canvas/js/wizard.js" type="text/javascript"></script>
<script src="assets/canvas/js/wizard_custom.js"></script>
<script src="assets/canvas/js/bmc_wizard_api.js"></script>
<!--end::Page Scripts -->

<script type="text/javascript">
	bmcWizardApi.init();
</script>

</body>
<!-- end::Body -->
</html>

<% webData.close(); %>

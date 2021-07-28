<!DOCTYPE html>
<html lang="en" >

    <!-- begin::Head -->
    <head>
        <meta charset="utf-8" />
        
        <title>Standup</title>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, shrink-to-fit=no">

		<!--begin::Global Theme Styles -->
		    <link href="assets/canvas/vendor/vendors.bundle.css" rel="stylesheet" type="text/css" />
		    <link href="assets/canvas/vendor/style.bundle.css" rel="stylesheet" type="text/css" />
		    <link href="assets/canvas/css/style.bundle.v=7.rtl.css" rel="stylesheet" type="text/css"/>
            <link href="assets/canvas/css/fontawesome.min.css" rel="stylesheet" type="text/css"/>
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
        <style type="text/css">
            @media screen and (min-width: 992px) {
                #kt_app_chat_toggle {
                display: none;
                }
            }
        </style>
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
	        
<div class="m-content .m-portlet">

    <!-- start page title -->
    <div class="row">
        <div class="col-12">
            <div class="page-title-box d-flex align-items-center justify-content-between">
                <h4 class="mb-0 font-size-18">Stand-up</h4>

                <div class="page-title-right">
                    <ol class="breadcrumb m-0">
                        <li class="breadcrumb-item"><a href="javascript: void(0);">Tasks</a></li>
                        <li class="breadcrumb-item active">Stand-up</li>
                    </ol>
                </div>

            </div>
        </div>
    </div>
    <!-- end page title -->

<!--Begin::Main Portlet-->
<div class="d-flex m-portlet ">
					
<!--begin::Content Wrapper-->
<div class="main d-flex flex-column flex-row-fluid">

<div class="content flex-column-fluid" id="kt_content">
<!--begin::Chat-->
<div class="d-flex flex-row">
    <!--begin::Aside-->
    <div class="flex-row-auto offcanvas-mobile w-300px" id="kt_chat_aside">
        <!--begin::Card-->
        <div class="card card-custom">
            <!--begin::Body-->
            <div class="card-body p-2">
                <!--begin:Search-->
                <div class="input-group input-group-solid search">
                    <div class="input-group-prepend">
                        <span class="input-group-text btn-sm">
                             <i class="fas fa-search"></i>
                         </span>
                    </div>
                    <input type="text" class="form-control py-2 h-auto" placeholder="Board">
                </div>
                <!--end:Search-->

                <div class="d-flex align-items-center justify-content-between p-2">
                    <div class="d-flex align-items-center">
                        <div class="d-flex flex-column">
                            <span class="font-weight-bold text-muted font-size-lg">Scrum Boards</span>
                        </div>
                    </div>
                </div>

                <!--begin:Users-->
                <div class="mt-1 scroll scroll-pull ps ps__rtl ps--active-y">
                    <div id="board-list">
                        
                    </div>
                <div class="ps__rail-x" style="left: 0px; bottom: 0px;"><div class="ps__thumb-x" tabindex="0" style="left: 0px; width: 0px;"></div></div><div class="ps__rail-y" style="top: 0px; height: 100px; right: 343px;"><div class="ps__thumb-y" tabindex="0" style="top: 0px; height: 40px;"></div></div></div>
                <!--end:Users-->
            </div>
            <!--end::Body-->
        </div>
        <!--end::Card-->
    </div>
    <!--end::Aside-->

    <!--begin::Content-->
    <div class="flex-row-fluid ml-lg-8" id="kt_chat_content">
        <!--begin::Card-->
        <div class="card card-custom">
            <!--begin::Header-->
            <div class="card-header align-items-center px-4 py-1">
                <div class="text-left flex-grow-1 row">
                    <button type="button" class="btn btn-clean btn-sm btn-icon btn-icon-md mr-3" id="kt_app_chat_toggle">
                        <i class="fas fa-bars"></i>
                    </button>

                	<h3 class="text-dark-75 font-weight-bold pt-1" name="" id="board-title">Board</h3>
                </div>
                <div class="text-right flex-grow-1">
                    <!--begin::Dropdown Menu-->
                    <button type="button" title="Refresh" id="refresh-button" class="btn btn-clean btn-sm btn-icon btn-icon-md">
                        <i class="fas fa-spinner"></i>
                    </button>
                    <div class="dropdown dropdown-inline">
                        <button type="button" title="Options" class="btn btn-clean btn-sm btn-icon btn-icon-md" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                        	<i class="fas fa-ellipsis-h"></i>
                        </button>
                        <div class="dropdown-menu p-0 m-0 dropdown-menu-right dropdown-menu-md">
                            <!--begin::Navigation-->
							<ul class="navi navi-hover py-3">
							    <li class="navi-item">
							        <a href="#" class="navi-link" data-toggle="modal" data-target="#details_modal" id="details-link">
							            <span class="navi-icon"><i class="fas fa-info-circle"></i></span>
							            <span class="navi-text">Standup Details</span>
							        </a>
							    </li>
							    <li class="navi-separator my-3"></li>

							    <li class="navi-item">
							        <a href="#" class="navi-link">
							            <span class="navi-icon"><i class="fas fa-question"></i></span>
							            <span class="navi-text">Help</span>
							        </a>
							    </li>
							</ul>
							<!--end::Navigation-->
                        </div>
                    </div>
                    <!--end::Dropdown Menu-->
                </div>
            </div>
            <!--end::Header-->
            <hr>
            <!--begin::Body-->
            <div class="card-body">
                <!--begin::Scroll-->
                <div class="scroll scroll-pull ps ps__rtl" data-mobile-height="350" style="overflow: hidden;">
                    <!--begin::Messages-->
                    <div class="messages border-bottom border-light" id="message-container">
                        
                    </div>
                    <!--end::Messages-->
                <div class="ps__rail-x" style="left: 0px; bottom: 0px;"><div class="ps__thumb-x" tabindex="0" style="left: 0px; width: 0px;"></div></div><div class="ps__rail-y" style="top: 0px; right: 497px;"><div class="ps__thumb-y" tabindex="0" style="top: 0px; height: 0px;"></div></div></div>
                <!--end::Scroll-->
            </div>
            <!--end::Body-->

            <!--begin::Footer-->
            <div class="dropdown card-footer align-items-center py-0">
                <!--begin::Compose-->
                <!-- <textarea class="form-control p-2 border border-secondary" data-toggle="modal" data-target="#standup_modal" id="message-input" rows="1" placeholder="Standup Message" disabled="disabled"></textarea> -->
                <textarea class="ckeditor form-control" rows="3" placeholder="Type a Message" id="message-input" name="message_input" placeholder="Type a message"></textarea>
                <div class="d-flex align-items-center justify-content-between mt-2">
                    <div class="col-md-4">
                        <button type="button" class="btn btn-primary btn-md text-uppercase font-weight-bold py-2 px-3" data-toggle="modal" data-target="#standup_modal" id="standupAddBtn" disabled="disabled">Add Standup</button>
                        <span class="m-form__help row px-3">Click to add Daily Standup.</span>
                    </div>
                    <div>
                        <span class="m-form__help text-danger d-none" id="err-msg">Type a message before submitting.</span>
                        <button type="button" class="btn btn-info btn-md text-uppercase font-weight-bold chat-send py-2 px-3" id="submitChat" disabled="disabled">Send Message</button>
                    </div>
                </div>
                <!--end::Compose-->
            </div>
            <!--end::Footer-->
        </div>
        <!--end::Card-->
    </div>
    <!--end::Content-->
</div>
<!--end::Chat-->
</div>
<!--end::Content-->
</div>
<!--begin::Content Wrapper-->
</div>

<!--End::Main Portlet--> 
    	 
</div>

</div>
<!-- end:: Body -->


<!--begin::Modal-->
<div class="modal fade" id="standup_modal" tabindex="-1" role="dialog" aria-labelledby="standupMessageModal" aria-hidden="true">
  <div class="modal-dialog modal-md" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title" id="standupLabel">Standup Message</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true"><i class="fas fa-times"></i></span>
        </button>
      </div>
      <form id="message-form">
          <div class="modal-body py-0">
              <div class="form-group">
                <label for="yesterday" class="form-control-label text-muted">Done Yesterday: * <span class="m-form__help text-danger d-none" id="err-yesterday">This field is required.</span></label>
                <textarea class="ckeditor form-control" name="yesterday" id="inputYesterday" required rows="3"></textarea>
                <!-- <div class="form-control" name="yesterday" id="inputYesterday" data-provide="markdown-editable" data-height="80" required></div> -->
              </div>
              <div class="form-group">
                <label for="todo" class="form-control-label text-muted">To Do Today: * <span class="m-form__help text-danger d-none" id="err-todo">This field is required.</span></label>
                <textarea class="ckeditor form-control" name="today" id="inputTodo" required rows="3"></textarea>
              </div>
              <div class="form-group">
                <label for="impediments" class="form-control-label text-muted">Impediments:</label>
                <textarea class="ckeditor form-control" name="impediments" id="inputImpediments" rows="2"></textarea>
              </div>
          </div>
          <div class="modal-footer pt-0 pb-1">
            <button type="button" class="btn btn-secondary border-secondary" data-dismiss="modal"><span class="text-dark">Close</span></button>
            <button type="button" class="btn btn-success text-uppercase" id="modalMessageSubmit">Send</button>
          </div>
      </form>
    </div>
  </div>
</div>


<!--begin::Modal-->
<div class="modal fade" id="details_modal" tabindex="-1" role="dialog" aria-labelledby="detailsModal" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-md" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Stand-Up Details</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true"><i class="fas fa-times"></i></span>
        </button>
      </div>
      <div class="modal-body">
          <div class="input-group">
            <label for="name" class="form-control-label mr-2">Name :</label>
            <h4 name="name" id="detailsTitle" class="form-control-label text-muted text-dark"></h4>
          </div>
          <div class="input-group">
            <label for="members" class="form-control-label mr-2">Members :</label>
            <h4 name="members" id="members" class="form-control-label text-muted text-dark"></h4>
          </div>
          <div class="input-group">
            <label for="time" class="form-control-label mr-2">Standup Time :</label>
            <h4 name="time" id="time" class="form-control-label text-muted text-dark"></h4>
          </div>
          <div class="form-group">
            <label for="details" class="form-control-label">Details: </label>
            <p class="text-dark font-size-sm mt-2" id="details"></p>
          </div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary border-secondary" data-dismiss="modal"><span class="text-dark">Close</span></button>
      </div>
    </div>
  </div>
</div>
<!--end::Modal-->
				
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
<script src="assets/canvas/js/app-full.js?ver=1.1"></script>

<script src="assets/global/plugins/ckeditor/ckeditor.js"></script>
<!--end::Global Theme Bundle -->

<script src="assets/canvas/libs/bootstrap/js/bootstrap-markdown.js"></script>
<script src="assets/canvas/libs/moment/moment.js"></script>
<script src="assets/canvas/js/standup_custom.js?ver=1.7"></script>
<script src="assets/canvas/js/standup_api.js?ver=1.7"></script>

<script type="text/javascript">
    standupApi.init();
</script>

<script type="text/javascript">
    $("#kt_app_chat_toggle").on('click', function() {
        $(".offcanvas-mobile-overlay").remove();
        $("#kt_chat_aside").toggleClass("offcanvas-mobile-on");
        $('<div class="offcanvas-mobile-overlay"></div>').insertAfter("#kt_chat_aside");

        $(".offcanvas-mobile-overlay").on('click', function() {
            $("#kt_chat_aside").toggleClass("offcanvas-mobile-on");
            $(".offcanvas-mobile-overlay").remove();
        });
    });
</script>

<script type="text/javascript">
    CKEDITOR.config.height = 100;
    CKEDITOR.config.toolbar =[
            ['Bold','Italic','Underline', 'Blockquote'],
            ['NumberedList','-','BulletedList'],            
            ['Image', 'Link'],
            ['Maximize']
            ];
    CKEDITOR.config.scayt_autoStartup = true;
    CKEDITOR.env.isCompatible = true;
</script>

</body>
<!-- end::Body -->
</html>

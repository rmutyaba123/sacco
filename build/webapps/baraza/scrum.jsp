<!doctype html>
<html lang="en">

<% 

	if(request.getParameter("data") != null) {
		session.setAttribute("scrumboardId", "-1");
		session.setAttribute("bmcId", request.getParameter("data"));
	}

%>

    <head>
        <meta charset="utf-8" />
        <title>Scrum Board</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta content="openbaraza Canvas Framework" name="description" />
        <meta content="Evingtone Ngoa, Dennis Gichangi" name="author" />
        <!-- App favicon -->
        <link rel="shortcut icon" href="assets/canvas/images/favicon.png">

        <!-- dragula css -->
        <link href="assets/canvas/libs/dragula/dragula.min.css" rel="stylesheet" type="text/css" />

        <!-- Bootstrap Css -->
        <link href="assets/canvas/css/bootstrap.min.css" id="bootstrap-style" rel="stylesheet" type="text/css" />
        <!-- Icons Css -->
        <link href="assets/canvas/css/icons.min.css" rel="stylesheet" type="text/css" />
        <!-- Summernote css -->
        <link href="assets/canvas/libs/summernote/summernote-bs4.min.css" rel="stylesheet" type="text/css" />
        <!-- App Css-->
        <link href="assets/canvas/css/app.min.css" id="app-style" rel="stylesheet" type="text/css" />
        <link href="assets/canvas/css/custom.css" id="app-style" rel="stylesheet" type="text/css" />
        <link href="assets/canvas/css/scrum_custom.css" id="app-style" rel="stylesheet" type="text/css" />

    </head>

    <body data-sidebar="dark">

        <!-- Begin page -->
        <div id="layout-wrapper">

            <%@ include file="./assets/include/canvas_header.jsp" %>

                <!-- ============================================================== -->
                <!-- Start right Content here -->
                <!-- ============================================================== -->
                <div class="main-content">

                    <div class="page-content">
                        <div class="container-fluid">

                            <!-- start page title -->
                            <div class="row" style="display: none;">
                                <div class="col-12">
                                    <div class="page-title-box d-flex align-items-center justify-content-between">
                                        <h4 class="mb-0 font-size-18">Scrum Board</h4>

                                        <div class="page-title-right">
                                            <ol class="breadcrumb m-0">
                                                <li class="breadcrumb-item"><a href="javascript: void(0);">Tasks</a></li>
                                                <li class="breadcrumb-item active">Scrum Board</li>
                                            </ol>
                                        </div>

                                    </div>
                                </div>
                            </div>
                            <!-- end page title -->


                            <!-- start row -->
                            <div class="row">
                                <!-- Product Backlog -->
                                <div class="col-lg-2 col-md-offset-1">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('31');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">Product Backlog</h4>
                                            <div id="product_backlog" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end Product Backlog -->

                                <!-- Sprint Backlog -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('32');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">Sprint Backlog</h4>
                                            <div id="sprint_backlog" class="pb-1 task-list">


                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end Sprint Backlog -->

                                <!-- Pain To Do -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('33');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">To Do</h4>
                                            <div id="to_do" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end To Do -->

                                <!-- In Progress -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('34');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">In Progress</h4>
                                            <div id="in_progress" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end In Progress -->

                                <!-- Review -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('35');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">Review</h4>
                                            <div id="review" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end Review -->

                                <!-- Done -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('36');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">Done</h4>
                                            <div id="done" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end Done -->

                                <!-- Impediments -->
                                <div class="col-lg-2">
                                    <div class="card">
                                        <div class="even card-body">
                                            <div class="dropdown float-right">
                                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false">
                                                    <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                                </a>
                                                <div class="dropdown-menu dropdown-menu-right">
                                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();openModal('37');">Add</a>

                                                </div>
                                            </div>
                                            <!-- end dropdown -->

                                            <h4 class="card-title mb-4">Impediments</h4>
                                            <div id="impediments" class="pb-1 task-list">

                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <!-- end Impediments -->

                            </div>
                            <!-- end row -->

                        </div>
                        <!-- container-fluid -->
                    </div>
                    <!-- End Page-content -->


                    <%@ include file="./assets/include/canvas_footer.jsp" %>
                </div>
                <!-- end main content-->

        </div>
        <!-- END layout-wrapper -->

        <!-- Add Modal -->
        <div class="modal fade" id="addCardModal" tabindex="-1" role="dialog" aria-labelledby="addCardModalLabel" aria-hidden="true">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="addModalTitle"></h5>
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    </div>
                    <form id="frmNote">
                        <div class="modal-body">
                            <!-- Message Alert -->
                            <div id="msgAlert">

                            </div>

                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Note Content:</label>
                                <textarea class="form-control summernote" id="note_content" name="note_content"></textarea>
                                <input type="hidden" class="form-control" id="note_segment" name="note_segment" value="">
                            </div>
                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Addditional Details:</label>
                                <textarea class="form-control summernote" id="note_additional_details" name="note_additional_details" value=""></textarea>
                            </div>
                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Select Label:</label>
                                <input type="hidden" class="form-control" id="note_label" name="note_label" value="">
                                <div class="note-color-pick">
                                    <!---->
                                    <!---->
                                    <div class="color-square an" onclick="selectChange('an')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square gn" onclick="selectChange('gn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square yn" onclick="selectChange('yn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square rn" onclick="selectChange('rn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square en" onclick="selectChange('en')">
                                    </div>
                                    <!---->
                                    <!---->
                                </div>
                            </div>

                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                            <button type="button" class="btn btn-primary btn-create">Create Card</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- Edit Modal -->
        <div class="modal fade" id="editCardModal" tabindex="-1" role="dialog" aria-labelledby="editCardModalLabel" aria-hidden="true">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="editModalTitle"></h5>
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    </div>
                    <form id="frmEditNote">
                        <div class="modal-body">
                            <!-- Message Alert -->
                            <div id="msgAlert">

                            </div>

                            <div class="form-group">
                                <label for="note_content_edit" class="col-form-label">Note Content:</label>
                                <textarea class="form-control summernote" id="note_content_edit" name="note_content" value=""></textarea>
                            </div>
                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Addditional Details:</label>
                                <textarea class="form-control summernote" id="note_additional_details_edit" name="note_additional_details" value=""></textarea>
                            </div>
                            <div class="form-group">
                                <label for="" class="col-form-label">Select Label:</label>
                                <input type="hidden" class="form-control" id="note_label" name="note_label" value="">
                                <input type="hidden" class="form-control" id="note_segment" name="note_segment" value="">
                                <input type="hidden" class="form-control" id="note_id" name="note_id" value="">
                                <div class="note-color-pick">
                                    <!---->
                                    <!---->
                                    <div class="color-square an" onclick="selectChange('an')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square gn" onclick="selectChange('gn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square yn" onclick="selectChange('yn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square rn" onclick="selectChange('rn')">
                                    </div>
                                    <!---->
                                    <!---->
                                    <!---->
                                    <div class="color-square en" onclick="selectChange('en')">
                                    </div>
                                    <!---->
                                    <!---->
                                </div>
                            </div>

                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                            <button type="button" class="btn btn-primary btn-edit">Edit Card</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- View Modal -->
        <div class="modal fade" id="viewCardModal" tabindex="-1" role="dialog" aria-labelledby="editCardModalLabel" aria-hidden="true">
            <div class="modal-dialog modal-lg" role="document">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title" id="viewModalTitle"></h5>
                        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    </div>
                    <form id="frmEditNote">
                        <div class="modal-body">
                            <!-- Message Alert -->
                            <div id="msgAlert">

                            </div>

                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Note Content:</label>
                                <div id="note_content_view"></div>
                            </div>
                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Additional Details:</label>
                                <div id="note_add_det_view"></div>
                            </div>
                            <div class="form-group">
                                <label for="note_content" class="col-form-label">Assigned:</label>
                                <div id="note_assignee_view"></div>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                            <!-- <button type="button" class="btn btn-primary btn-edit">Edit Card</button> -->
                        </div>
                    </form>
                </div>
            </div>
        </div>

        <!-- Right Sidebar -->
        <div class="right-bar">
            <div data-simplebar class="h-100">
                <div class="rightbar-title px-3 py-4">
                    <a href="javascript:void(0);" class="right-bar-toggle float-right">
                        <i class="mdi mdi-close noti-icon"></i>
                    </a>
                    <h5 class="m-0">View Archived Cards</h5>
                </div>


                <div class="p-4" id="appendArchived">
                    <div class="card task-box rn" id="task_8" style="display: none;">
                        <div class="card-body">
                            <!-- Dropdown options -->
                            <div class="dropdown float-right">
                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false"><i class="mdi mdi-dots-vertical m-0 text-muted h5"></i></a>
                                <div class="dropdown-menu dropdown-menu-right">
                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();unarchive('8');"><i class="bx bx-archive-in"></i> Restore To Board</a>
                                    <a class="dropdown-item delete" href="#" onclick="event.preventDefault();deleteNote('8');"><i class="bx bx-trash"></i> Delete</a>
                                </div>
                            </div>
                            <!--End Dropdown options-->
                            <div><a href="javascript: void(0);" class="text-muted">Create a sample of banner and flyers we could use.</a></div>
                        </div>
                    </div>
                    <div class="card task-box rn" id="task_8" style="display: none;">
                        <div class="card-body">
                            <!-- Dropdown options -->
                            <div class="dropdown float-right">
                                <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown" aria-expanded="false"><i class="mdi mdi-dots-vertical m-0 text-muted h5"></i></a>
                                <div class="dropdown-menu dropdown-menu-right">
                                    <a class="dropdown-item" href="#" onclick="event.preventDefault();unarchive('8');"><i class="bx bx-archive-in"></i> Restore To Board</a>
                                    <a class="dropdown-item delete" href="#" onclick="event.preventDefault();deleteNote('8');"><i class="bx bx-trash"></i> Delete</a>
                                </div>
                            </div>
                            <!--End Dropdown options-->
                            <div><a href="javascript: void(0);" class="text-muted">Create a sample of banner and flyers we could use.</a></div>
                        </div>
                    </div>
                </div>

            </div>
            <!-- end slimscroll-menu-->
        </div>
        <!-- /Right-bar -->

        <!-- JAVASCRIPT -->
        <script src="assets/canvas/libs/jquery/jquery.min.js"></script>
        <script src="assets/canvas/libs/bootstrap/js/bootstrap.bundle.min.js"></script>
        <script src="assets/canvas/libs/metismenu/metisMenu.min.js"></script>
        <script src="assets/canvas/libs/simplebar/simplebar.min.js"></script>
        <script src="assets/canvas/libs/node-waves/waves.min.js"></script>

        <!-- dragula plugins -->
        <script src="assets/canvas/libs/dragula/dragula.min.js"></script>

        <script src="assets/canvas/js/app-full.js"></script>
        <script src="assets/canvas/js/scrum_custom.js"></script>
        <script src="assets/canvas/js/scrum_api.js"></script>

        <script type="text/javascript">
            scrumApi.init();
        </script>

        <!-- Summernote js -->
        <script src="assets/canvas/libs/summernote/summernote-bs4.min.js"></script>

        <script src="assets/canvas/js/scrum_canvas.init.js"></script>
        <script src="assets/canvas/js/canvas.js"></script>

    </body>

</html>
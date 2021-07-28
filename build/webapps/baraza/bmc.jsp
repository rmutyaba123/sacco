<!doctype html>
<html lang="en">

<% 

	if(request.getParameter("data") != null) {
		session.setAttribute("bmcId", request.getParameter("data"));
	}

%>

<head>
    <meta charset="utf-8" />
    <title>BMC Canvas</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta content="openbaraza BMC Framework" name="description" />
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
                    <div class="row">
                        <div class="col-12">
                            <div class="page-title-box d-flex align-items-center justify-content-between">
                                <h4 class="mb-0 font-size-18">BMC Board</h4>

                                <div class="page-title-right">
                                    <ol class="breadcrumb m-0">
                                        <li class="breadcrumb-item"><a href="javascript: void(0);">Tasks</a></li>
                                        <li class="breadcrumb-item active">BMC Board</li>
                                    </ol>
                                </div>

                            </div>
                        </div>
                    </div>
                    <!-- end page title -->

                    <!-- start row -->
                    <div class="row">
                        <div class="col-lg-2 col-md-offset-1">
                            <div class="card">
                                <div class="even card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('17');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Key Partners</h4>
                                    <div id="key-partners" class="pb-1 task-list">

                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- end col -->

                        <div class="col-lg-2">
                            <!-- Key Activities -->
                            <div class="card" style="margin-bottom: 0px;">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('15');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Key Activities</h4>
                                    <div id="key-activities" class="pb-1 task-list">

                                    </div>
                                </div>
                            </div>
                            <!-- End Key Activities -->

                            <!-- Key Resources -->
                            <div class="card">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('16');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Key Resources</h4>
                                    <div id="key-resources" class="pb-1 task-list">

                                    </div>
                                </div>
                            </div>
                            <!-- End Key Resources -->
                        </div>
                        <!-- end col -->

                        <div class="col-lg-2">
                            <div class="card">
                                <div class="even card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('10');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Value Propositions</h4>
                                    <div id="value-propositions" class="pb-1 task-list">


                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- end col -->

                        <div class="col-lg-2">
                            <!-- Customer Relationships -->
                            <div class="card" style="margin-bottom: 0px;">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('13');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Customer Relationships</h4>
                                    <div id="customer-relationships" class="pb-1 task-list">

                                        <!-- start task card -->

                                        <!-- end task card -->


                                    </div>
                                </div>
                            </div>
                            <!-- End Customer Relationships -->

                            <!-- Channels  -->
                            <div class="card">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('11');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Channel</h4>
                                    <div id="channels" class="pb-1 task-list">

                                        <!-- start task card -->

                                        <!-- end task card -->


                                    </div>
                                </div>
                            </div>
                            <!-- End Channels  -->
                        </div>
                        <!-- end col -->

                        <div class="col-lg-2">
                            <div class="card">
                                <div class="even card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('12');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Customer Segments</h4>
                                    <div id="customer-segments" class="pb-1 task-list">

                                        <!-- start task card -->

                                        <!-- end task card -->


                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- end col -->

                        <!-- Bottom -->

                        <div class="col-lg-6 col-md-offset-1">
                            <div class="card">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('18');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Cost Structure</h4>
                                    <div id="cost-structure" class="pb-1 task-list">


                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- end col -->

                        <div class="col-lg-6 col-md-offset-1">
                            <div class="card">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('14');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Revenue Streams</h4>
                                    <div id="revenue-streams" class="pb-1 task-list">


                                    </div>
                                </div>
                            </div>
                        </div>
                        <!-- end col -->

                    </div>
                    <!-- end row -->

                    <!-- Brainstorm -->
                    <div class="row">
                        <div class="col-lg-12 col-md-offset-1" style="padding: 0px;">
                            <div class="card">
                                <div class="odd card-body">
                                    <div class="dropdown float-right">
                                        <a href="#" class="dropdown-toggle arrow-none" data-toggle="dropdown"
                                            aria-expanded="false">
                                            <i class="mdi mdi-dots-vertical m-0 text-muted h5"></i>
                                        </a>
                                        <div class="dropdown-menu dropdown-menu-right">
                                            <a class="dropdown-item" href="#"
                                                onclick="event.preventDefault();openModal('19');">Add</a>

                                        </div>
                                    </div> <!-- end dropdown -->

                                    <h4 class="card-title mb-4">Brainstorm</h4>
                                    <div id="brainstorm" class="pb-1 task-list">


                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    <!-- End Brainstorm -->

                </div> <!-- container-fluid -->
            </div>
            <!-- End Page-content -->

            <%@ include file="./assets/include/canvas_footer.jsp" %>

        </div>
        <!-- end main content-->

    </div>
    <!-- END layout-wrapper -->

    <!-- Add Modal -->
    <div class="modal fade" id="addCardModal" tabindex="-1" role="dialog" aria-labelledby="addCardModalLabel"
        aria-hidden="true">
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
                            <textarea class="form-control summernote" id="note_additional_details" name="note_additional_details"
                                value=""></textarea>
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
    <div class="modal fade" id="editCardModal" tabindex="-1" role="dialog" aria-labelledby="editCardModalLabel"
        aria-hidden="true">
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
                            <label for="note_content" class="col-form-label">Note Content:</label>
                            <textarea class="form-control summernote" id="note_content_edit" name="note_content" value=""></textarea>
                        </div>
                        <div class="form-group">
                            <label for="note_content" class="col-form-label">Addditional Details:</label>
                            <textarea class="form-control summernote" id="note_additional_details_edit" name="note_additional_details"
                                value=""></textarea>
                        </div>
                        <div class="form-group">
                            <label for="note_content_edit" class="col-form-label">Select Label:</label>
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
    <div class="modal fade" id="viewCardModal" tabindex="-1" role="dialog" aria-labelledby="editCardModalLabel"
        aria-hidden="true">
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

                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                        <!-- <button type="button" class="btn btn-primary btn-edit">Edit Card</button> -->
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- JAVASCRIPT -->
    <script src="assets/canvas/libs/jquery/jquery.min.js"></script>
    <script src="assets/canvas/libs/bootstrap/js/bootstrap.bundle.min.js"></script>
    <script src="assets/canvas/libs/metismenu/metisMenu.min.js"></script>
    <script src="assets/canvas/libs/simplebar/simplebar.min.js"></script>
    <script src="assets/canvas/libs/node-waves/waves.min.js"></script>

    <!-- dragula plugins -->
    <script src="assets/canvas/libs/dragula/dragula.min.js"></script>

    <script src="assets/canvas/js/app-full.js"></script>
    <script src="assets/canvas/js/bmc_custom.js"></script>
    <script src="assets/canvas/js/bmc_api.js"></script>

    <script type="text/javascript">
        bmcApi.init();
    </script>

    <!-- Summernote js -->
    <script src="assets/canvas/libs/summernote/summernote-bs4.min.js"></script>

    <script src="assets/canvas/js/bmc_canvas.init.js"></script>
    <script src="assets/canvas/js/canvas.js"></script>

</body>

</html>
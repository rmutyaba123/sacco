
<%

	BElement elSearch = web.getViewByName("SEARCH");
	String jsFunct = elSearch.getAttribute("jsfunct");
	jsFunct += "(val);";
	
	String jqsGridHead = "";
	if(elSearch != null) {
		int subNo = web.getView().getSubByName("SEARCH");
		String subViewKey = web.getViewKey() + ":" + subNo;
		jqsGridHead =  web.getJSONHeader(elSearch, subViewKey);

	}

%>


<!--begin::Modal-->
<div class="modal fade" id="search_modal_id" role="dialog" aria-labelledby="detailsModal" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-md" role="document">
    <div class="modal-content">
      <div class="modal-header">
        <h5 class="modal-title">Search</h5>
        <button type="button" class="close" data-dismiss="modal" aria-label="Close">
          <span aria-hidden="true"><i class="fas fa-times"></i></span>
        </button>
      </div>
      <div class="modal-body" id="modal_body_id">
		<div class='table-scrollable'>
		<table id='jqslist' class='table table-striped table-bordered table-hover'></table>
		<div id='jqspager'></div>
		</div>
      </div>
      <div class="modal-footer">
        <button type="button" class="btn btn-secondary border-secondary" data-dismiss="modal"><span class="text-dark">Close</span></button>
      </div>
    </div>
  </div>
</div>
<!--end::Modal-->

<script>

	$('#btnSearch').click(function(){	
		$("#search_modal_id").modal();
	});
	
    var jqscf = <%= jqsGridHead %>;

    jqscf.rowNum = 30;
    jqscf.height = 300;
    jqscf.rowList=[10,20,30,40,50];
    jqscf.datatype = "json";
    jqscf.pgbuttons = true;
	jqscf.autoencode = false;
	jqscf.ignoreCase = true;

    jqscf.jsonReader = {
        repeatitems: false,
        root: function (obj) { return obj; },
        page: function (obj) { return jQuery("#jqslist").jqGrid('getGridParam', 'page'); },
        total: function (obj) { return Math.ceil(obj.length / jQuery("#jqslist").jqGrid('getGridParam', 'rowNum')); },
        records: function (obj) { return obj.length; }
    }
    
    jqscf.ondblClickRow = function(rowid) {
    	console.log('Row double clicked');
		console.log(rowid);
		var data = jQuery("#jqslist").jqGrid('getRowData',rowid);
		console.log(data.KF);
		
		modalSetValue(data.KF);
	};

    //console.log(jqscf);

    jQuery("#jqslist").jqGrid(jqscf);
    jQuery("#jqslist").jqGrid("navGrid", "#jqspager", {edit:false, add:false, del:false, search:false});
    jQuery("#jqslist").jqGrid("filterToolbar", { stringResult: true, searchOnEnter: false, defaultSearch: "cn" });

    
    $('#jqslist').setGridWidth(500, true);
    
	function modalSetValue(val) {
		console.log('Set Value');
		console.log(val);
		
		<%= jsFunct %>
		
		$('#search_modal_id').modal('hide');
	}
	
</script>

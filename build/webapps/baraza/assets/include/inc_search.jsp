

<script>

    var jqscf = <%= jqGridHead %>;

    jqscf.rowNum = 30;
    jqscf.height = 300;
    jqscf.rowList=[10,20,30,40,50];
    jqscf.datatype = "json";
    jqscf.pgbuttons = true;
	jqscf.autoencode = false;
	jqscf.editurl = "ajaxupdate";

    jqscf.jsonReader = {
        repeatitems: false,
        root: function (obj) { return obj; },
        page: function (obj) { return jQuery("#jqslist").jqGrid('getGridParam', 'page'); },
        total: function (obj) { return Math.ceil(obj.length / jQuery("#jqslist").jqGrid('getGridParam', 'rowNum')); },
        records: function (obj) { return obj.length; }
    }

    //console.log(jqscf);

    jQuery("#jqslist").jqGrid(jqscf);
    jQuery("#jqslist").jqGrid("navGrid", "#jqspager", {edit:false, add:false, del:false, search:false});


</script>




<script>
    $(document).ready(function() {
        var data_get_map = {'frm_general_settings':"/api/gatus/general/get"};
        mapDataToFormUI(data_get_map).done(function(data) {
            formatTokenizersUI();
            $('.selectpicker').selectpicker('refresh');
            $('#general\\.config').css('font-family', 'monospace');
        });

        ajaxCall(url="/api/gatus/service/status", sendData={}, callback=function(data,status) {
            updateServiceStatusUI(data['status']);
        });

        $("#saveAct").click(function() {
            saveFormToEndpoint(url="/api/gatus/general/set", formid='frm_general_settings', callback_ok=function() {
                $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
                ajaxCall(url="/api/gatus/service/reconfigure", sendData={}, callback=function(data,status) {
                    ajaxCall(url="/api/gatus/service/status", sendData={}, callback=function(data,status) {
                        updateServiceStatusUI(data['status']);
                    });
                    $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                });
            });
        });
    });
</script>

<div class="content-box" style="padding-bottom: 1.5em;">
    {{ partial("layout_partials/base_form", ['fields':generalForm,'id':'frm_general_settings']) }}
    <div class="col-md-12">
        <hr />
        <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
    </div>
</div>

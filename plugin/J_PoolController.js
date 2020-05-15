/*
 * NodeJS Pool Controller Plugin
 * Copyright (C) 2020 Robert Strouse

 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */
var pcpConfig = (function (api) {
    var device = api.getCpanelDeviceId();
    var cfg = {};
    var dlgMgr = {
        showModalDialog: function (attrs) {
            var dlg = jQuery('#pcp_modalDialog');
            if (!this.isIntialized) {
                if (typeof dlg.draggable === 'function')
                    dlg.draggable({ handle: '#pcp_modalTitle', containment: '#pcp_modalOverlay', scroll: false });
            }
            var ovly = jQuery('#pcp_modalOverlay');
            jQuery('#pcp_modalTitleText').html(attrs.title);
            dlg[0].style.width = attrs.width;
            jQuery('#pcp_modalContent').html(attrs.content);
            ovly.show();
            dlg[0].style.left = ((ovly[0].parentElement.offsetWidth / 2) - (parseInt(attrs.width, 10) / 2)) + 'px';
            if (typeof jQuery(window).scrollTop === 'function')
                dlg[0].style.top = jQuery(window).scrollTop() + "px";
            if (typeof (attrs.init) === 'function') attrs.init();

            if (attrs.buttons && attrs.buttons.length > 0) {
                var btnPane = jQuery('#pcp_modalButtons');
                pcp_modalButtons.style.display = '';
                btnPane.html('');
                jQuery('<div style="display:inline;padding-left:4px;padding-right:4px;color:red;" id="pcp_modalStatusBar"/>').appendTo(btnPane[0]);
                for (var i = 0; i < attrs.buttons.length; i++) {
                    var btn = attrs.buttons[i];
                    if (typeof (btn.align) !== 'undefined' && btn.align === 'left')
                        jQuery('<input id="pcp_modalButton' + i + '" class="vBtn pull-left" type="button" style="margin:2px;" value="' + btn.text + '"></input>').appendTo(btnPane[0]);
                    else
                        jQuery('<input id="pcp_modalButton' + i + '" class="vBtn pull-right" type="button" style="margin:2px;" value="' + btn.text + '"></input>').appendTo(btnPane[0]);
                    var b = jQuery('#pcp_modalButton' + i);
                    if (typeof btn.event !== 'undefined') {
                        if (typeof b.click !== 'function')
                            pnl.bindControlEvent('#pcp_modalButtons', 'click', '#pcp_modalButton' + i, btn.event);
                        else
                            b.click(btn.event);
                    }
                }
                btnPane.show();
            }
            else
                pcp_modalButtons.style.display = "none";
            for (var p in attrs.params) {
                jQuery('#pcp_modalContent').data(p, attrs.params[p]);
            }
            dlg.show();
            dlg.css("position", "absolute");

        },
        resizeTo: function (width, bCenter) {
            var dlg = jQuery('#pcp_modalDialog');
            var ovly = jQuery('#pcp_modalOverlay');
            dlg[0].style.width = width;
            if (bCenter) dlg[0].style.left = ((ovly[0].parentElement.offsetWidth / 2) - (parseInt(width, 10) / 2)) + 'px';
        },
        showStatusDialog: function (attrs) {
            attrs.content = '<div style="padding:7px;text-align:center;">' + attrs.message + '</div>';
            this.showModalDialog(attrs);
        },
        showMessageDialog: function (attrs) {
            attrs.content = '<div style="padding:7px;text-align:center;">' + attrs.message + '</div>';
            if (!attrs.buttons || attrs.buttons.length === 0) {
                attrs.buttons = [{ text: "Close", event: function (evt) { dlgMgr.closeDialog(); } }];
            }
            this.showModalDialog(attrs);
        },
        closeDialog: function () { jQuery('#pcp_modalDialog').hide(); jQuery('#pcp_modalOverlay').hide(); }
    };
    var pnl = {
        reloadLuup: function () { },
        enablePanelControls: function (pnlSelector, bEnable) {
            jQuery(pnlSelector).find('.pcp_editField, .pcp_checkbox').each(function () {
                var bSkip = typeof jQuery(this).data('skipenable') === 'undefined' ? false : jQuery(this).data('skipenable');
                if (!bSkip) this.disabled = !bEnable;
            });
        },
        createConfigWindow: function (sTitle) {
            return '<div id="pcp_modalOverlay" style="opacity:.5;display:none;background-color:#EEEEEE;height:100%;left:0;top:0;min-height:100%;min-width:100%;position:fixed;text-align:center;z-index:10002;"/>'
                + '<div id="pcp_modalDialog" class="pcp_dialogShadow" style="font-size:8pt;border-top-left-radius:4px;border-top-right-radius:4px;display:none;position:absolute;margin:0px auto;width:400px;border:solid 1px silver;background-color:white;z-index:10003">'
                + '<div id="pcp_modalTitle" class="pcp_modalTitle pcp_titleGradient" style=""><span id="pcp_modalTitleText" style="color:white;font-weight:bold;">Modal Title</span><div class="pull-right" style="border:solid 1px silver;border-radius:2px;margin-top:-2px;display:inline-block;background-color:gainsboro;cursor:pointer;margin-bottom:2px;padding-bottom:4px;vertical-align:middle;height:18px;" onmouseover="this.style.backgroundColor=\'orange\';" onmouseout="this.style.backgroundColor=\'gainsboro\';"><img style="height:14px;margin:0px auto;vertical-align:middle;" src="skins/default/img/other/button_close.png" onclick="jQuery(\'#pcp_modalDialog\').hide(); jQuery(\'#pcp_modalOverlay\').hide();"/></div></div>'
                + '<div id="pcp_modalContent" style="font-size:8pt;width:100%;display:block;position:relative;font-size:9pt;padding-bottom:4px;"></div>'
                + '<div id="pcp_modalButtons" style="width:100%;padding-top:7px;border-top:solid 3px orange;height:50px;display:block;"></div></div>'
                + '<div class="pcp_cfgTitle">' + sTitle + '</div><div class="pcp_cfgMessages" />';
        },
        createConfigPanel: function (id, sTitle) {
            return '<div class="pcp_cfgPanel"><div class="pcp_dialogSubHeader" style="padding-left:4px;padding-right:4px;border-bottom:solid 2px orange;">' + sTitle + '</div><div class="pcp_cfgPanelContent"' + 'id="' + id + '">Loading...</div></div>';
        },
        createMessagePanel: function (id, message) { return '<div class="pcp_cfgPanelContent"' + 'id="' + id + '">' + message + '</div>'; },
        createGradient: function (gradFrom, gradTo) {
            return 'background-image:-webkit-gradient(linear, 0% 0%, 0% 100%, from(#' + gradFrom + '), to(#' + gradTo + ')); '
                + 'background-image:-webkit-linear-gradient(top, #' + gradFrom + ', #' + gradTo + '); '
                + 'background-image:-moz-linear-gradient(top, #' + gradFrom + ', #' + gradTo + '); '
                + 'background-image:-ms-linear-gradient(top, #' + gradFrom + ', #' + gradTo + '); '
                + 'background-image:-o-linear-gradient(top, #' + gradFrom + ', #' + gradTo + '); '
                + 'background-image:linear-gradient(top, #' + gradFrom + ', #' + gradTo + '); '
                + 'filter:progid:DXImageTransform.Microsoft.Gradient(GradientType=0, StartColorStr=#FF' + gradFrom + ', EndColorStr=#FF' + gradTo + ');';
        },
        createCheckboxRow: function (id, sLabel, value, attrs) {
            var help = '';
            var html = '<tr id="row_' + id + '" class="pcp_formRow">'
                + '<td style="width:200px;padding-left:4px;padding-right:4px;"><label class="pcp_label" for="' + id + '">' + sLabel + '</label>'
                + '<td style="padding-left:4px;padding-right:4px;"><input class="pcp_checkbox" type="checkbox" id="' + id + '"' + ((value === true || value === 1 || value === "1") ? ' checked="checked"' : '');
            if (attrs && typeof (attrs) !== 'undefined') {
                for (var s in attrs) {
                    if (s === 'helpText')
                        help = '<div class="pcpinst" style="position:absolute;max-width:397px;margin-left:34px;display:none;font-size:8pt;border:solid 1px teal;background-color:lightyellow;border-radius:4px;padding-left:4px;padding-right:4px;">' + attrs[s] + '</div>';
                    else
                        html += ' ' + s + '= "' + attrs[s] + '"';
                }
            }
            return html + '/>' + help + '</td></tr>';
        },
        createInputRow: function (id, sLabel, value, attrs) {
            return '<tr id="row_' + id + '" class="pcp_formRow">'
                + '<td style="width:200px;padding-left:4px;padding-right:4px;"><label class="pcp_label" for="' + id + '">' + sLabel + '</label>'
                + '<td style="padding-left:4px;padding-right:4px;">'
                + pnl.createInputField(id, value, attrs) + '</td></tr>';
        },
        createInputField: function (id, value, attrs) {
            var help = '';
            var suffix = '';
            var type = 'text';
            var html = '<input class="pcp_editField" id="' + id + '"' + ' value="' + ((value !== null && typeof value !== 'undefined') ? value : '') + '"';
            if (attrs && typeof attrs !== 'undefined') {
                for (var s in attrs) {
                    if (s === 'helpText')
                        help = '<div class="pcpinst" style="position:absolute;max-width:397px;margin-left:34px;display:none;font-size:8pt;border:solid 1px teal;background-color:lightyellow;border-radius:4px;padding-left:4px;padding-right:4px;">' + attrs[s] + '</div>';
                    else if (s === 'type')
                        type = attrs[s];
                    else if (s === 'suffix')
                        suffix = '<div style="vertical-align:middle;display:inline-block;">' + attrs[s] + '</div>';
                    else
                        html += ' ' + s + '= "' + attrs[s] + '"';
                }
            }
            return html + ' type="' + type + '"/>' + suffix + help;
        },
        createInfoRow: function (id, sLabel, sInfo, attrs) {
            var help = '';
            var html = '<tr id="row_nfo_' + id + '" title="" onmouseover="jQuery(this).find(\'div.pcpinst\').show();" onmouseout="jQuery(this).find(\'div.pcpinst\').hide();">'
                + '<td style="width:200px;padding-left:4px;padding-right:4px;"><label class="pcp_label" for="nfo_' + id + '">' + sLabel + '</label>'
                + '<td style="padding-left:4px;padding-right:4px;"><span class="pcp_editField" type="text" id="nfo_' + id + '"';
            if (attrs && typeof (attrs) !== 'undefined') {
                for (var s in attrs) {
                    if (s === 'helpText')
                        help = '<div class="pcpinst" style="position:absolute;width:300px;margin-left:54px;display:none;font-size:8pt;border:solid 1px teal;background-color:lightyellow;border-radius:4px;padding-left:4px;padding-right:4px;">' + attrs[s] + '</div>';
                    else
                        html += ' ' + s + '= "' + attrs[s] + '"';
                }
            }
            return html + '>' + ((sInfo !== null && typeof sInfo !== 'undefined') ? sInfo : '') + '</span>' + help + '</td></tr>';
        },
        createDropdownRow: function (id, sLabel, value, options, attrs) {
            var help = '';
            var html = '<tr id="row_' + id + '" class="pcp_formRow">'
                + '<td style="width:200px;padding-left:4px;padding-right:4px;"><label class="pcp_label" for="' + id + '">' + sLabel + '</label>'
                + '<td style="padding-left:4px;padding-right:4px;"><select class="pcp_editField" id="' + id + '"' + ' value="' + ((value !== null && typeof value !== 'undefined') ? value : '') + '"';
            if (attrs && typeof (attrs) !== 'undefined') {
                for (var s in attrs) {
                    if (s === 'helpText')
                        help = '<div class="pcpinst" style="position:absolute;max-width:397px;margin-left:34px;display:none;font-size:8pt;border:solid 1px teal;background-color:lightyellow;border-radius:4px;padding-left:4px;padding-right:4px;">' + attrs[s] + '</div>';
                    else
                        html += ' ' + s + '= "' + attrs[s] + '"';
                }
            }
            html += '>';
            for (var i = 0; i < options.length; i++) {
                html += '<option value="' + options[i].value + '" ' + ((value !== null && options[i].value.toString() === value.toString()) ? 'selected="selected"' : '') + '>' + options[i].text + '</option>';
            }
            return html + '</select>' + help + '</td></tr>';
        },
        bindValue: function (obj, elField, val, arrayRef) {
            var binding = jQuery(elField).data('bind');
            if (binding && binding.length > 0) {
                var sRef = '';
                var arr = binding.split('.');
                var t = obj;
                for (var i = 0; i < arr.length - 1; i++) {
                    s = arr[i];
                    if (typeof s === 'undefined' || s.length === 0) continue;
                    sRef += ('.' + s);
                    var ndx = s.lastIndexOf('[')
                    if (ndx !== -1) {
                        var v = s.substring(0, ndx);
                        var ndxEnd = s.lastIndexOf(']');
                        var ord = parseInt(s.substring(ndx + 1, ndxEnd), 10);
                        if (isNaN(ord)) ord = 0;
                        if (arrayRef[sRef] === undefined) {
                            if (t[v] === undefined) {
                                t[v] = new Array();
                                t[v].push(new Object());
                                t = t[v][0];
                                arrayRef[sRef] = ord;
                            }
                            else {
                                k = arrayRef[sRef];
                                if (k === undefined) {
                                    a = t[v];
                                    k = a.length;
                                    arrayRef[sRef] = k;
                                    a.push(new Object());
                                    t = a[k];
                                }
                                else
                                    t = t[v][k];
                            }
                        }
                        else {
                            k = arrayRef[sRef];
                            if (k === undefined) {
                                a = t[v];
                                k = a.length;
                                arrayRef[sRef] = k;
                                a.push(new Object());
                                t = a[k];
                            }
                            else
                                t = t[v][k];
                        }
                    }
                    else if (t[s]=== undefined) {
                        t[s] = new Object();
                        t = t[s];
                    }
                    else
                        t = t[s];
                }
                t[arr[arr.length - 1]] = val;
            }
        },
        getCheckedValue: function (sel) {
            if (typeof (sel).is === 'function')
                return sel.is(':checked');
            return sel.attr('checked');
        },
        setCheckedValue: function (sel, val) {
            if (typeof (sel.prop) === 'function')
                sel.prop('checked', val);
            else
                sel.attr('checked', val);
        },
        fromWindow: function (selector, o, ar) {
            var obj = typeof o === 'undefined' ? {} : o;
            var arryRef = typeof ar === 'undefined' ? {} : ar;
            jQuery(selector).each(function () {
                jQuery(this).find('input').each(function () {
                    var type = '';
                    if (typeof (jQuery(this).prop) === 'function')
                        type = jQuery(this).prop('type');
                    else
                        type = jQuery(this).attr('type');
                    var val = null;
                    switch (type) {
                        case 'number':
                            var sval = jQuery(this).val();
                            if (sval.indexOf('.') === -1)
                                val = parseInt(sval, 10);
                            else
                                val = parseFloat(sval);
                            if (isNaN(val)) val = null;
                            break;
                        case 'checkbox':
                            val = pnl.getCheckedValue(jQuery(this));
                            break;
                        default:
                            val = jQuery(this).val();
                            break;
                    }
                    pnl.bindValue(obj, this, val, arryRef);
                });
                jQuery(this).find('select').each(function () {
                    var type = jQuery(this).data('datatype');
                    type = (typeof (type) === 'undefined' || !type) ? type = '' : type;
                    var val = null;
                    switch (type) {
                        case 'number':
                            val = parseInt(jQuery(this).val(), 10);
                            if (isNaN(val)) val = null;
                            break;
                        default:
                            val = jQuery(this).val();
                            break;
                    }
                    pnl.bindValue(obj, this, val, arryRef);
                });
            });
            return obj;
        },
        loadPanelConfig: function (device, panelId, functionName, args, callback) {
            //console.log();
            callback(api.getDeviceObject(device));
            //try {
            //    var params = { id: 'lr_' + functionName, rand: Math.random(), output_format: 'json', pcp_deviceId: device };
            //    if (args && typeof (args) !== 'undefined') {
            //        for (var i = 0; i < args.length; i++)
            //            params[args[i].name] = args[i].value;
            //    }
            //    new Ajax.Request("../port_3480/data_request", {
            //        method: "get",
            //        pcp_deviceId: device,
            //        parameters: params,
            //        onSuccess: function (response) {
            //            var configuration = JSON.parse(response.responseText);
            //            if (typeof configuration !== 'undefined') {
            //                console.log(configuration);
            //                callback(configuration);
            //            }
            //            else
            //                jQuery('#' + panelId).html(response.responseText);
            //        },
            //        onFailure: function (response) {
            //            jQuery('#' + panelId).html('<p style="font-weight: bold; text-align: center;background-color:red;color:yellow;">' + functionName + ' call failed:' + response.statusText + '</p>'
            //                + '<p style="text-align:center"><ul style="text-align:left"><li>You must be connected locally to make changes to the plugin not through home.getvera.com</li><li>If Vera is currently reloading the Luup engine please try again</li></ul>');
            //        }
            //    });
            //}
            //catch (err) {
            //    jQuery('#' + panelId).html('<p style="font-weight: bold; text-align: center;background-color:red;color:yellow;">Error communicating with Vera. ' + functionName + ': ' + err.message + '</p>');
            //}
        },
        commitChildren: function () {
            try {
                new Ajax.Request("../port_3480/data_request", {
                    method: "get",
                    parameters: {
                        id: "lr_CommitAtjChildren",
                        pcp_deviceId: device,
                        rand: Math.random(),
                        output_format: "json"
                    },
                    onSuccess: function (response) {
                        dlgMgr.closeDialog();
                        if (jQuery('#pcp_btnSaveChanges').length > 0)
                            jQuery('#pcp_btnSaveChanges').hide()
                    },
                    onFailure: function () {
                        dlgMgr.closeDialog();
                        dlgMgr.showMessageDialog({
                            title: 'Error',
                            width: '350px',
                            message: 'Error saving configuration'
                        });
                    }
                });
            }
            catch (err) { console.log(err); }

        },
        bindControlEvent: function (id, evt, filter, fn) {
            if (arguments.length === 4) {
                if (typeof (jQuery().on) === 'function') {
                    console.log('Setting [' + evt + '] Event: ' + id + ' ' + 'Filter:' + filter);
                    jQuery(id).on(evt, filter, fn);
                }
                else {
                    console.log('Binding [' + evt + '] Event: ' + id + ' ' + 'Filter:' + filter);
                    jQuery(id).find(filter).bind(evt, fn);
                }
            }
            else {
                if (typeof (jQuery().on) === 'function') {
                    console.log('Setting [' + evt + '] Event: ' + id + ' ' + 'Filter: none');
                    jQuery(id).on(evt, filter);
                }
                else if (typeof (jQuery().bind) === 'function') {
                    console.log('Binding [' + evt + '] Event: ' + id + ' ' + 'Filter: none');
                    jQuery(id).bind(evt, filter);
                }
            }
        },
        showHelpPopup: function (elParent, bShow) {
            var p = jQuery(elParent).find('div.pcpinst');
            if (bShow) p.show();
            else p.hide();
        },
        setPanelHtml: function (id, html) {
            jQuery(id).html(html);
            pnl.bindControlEvent(id, 'click', 'input.pcp_checkbox', function () { jQuery('#pcp_btnSaveChanges').show(); });
            pnl.bindControlEvent(id, 'change', '.pcp_editField', function () { jQuery('#pcp_btnSaveChanges').show(); });
            pnl.bindControlEvent(id, 'mouseover', '.pcp_formRow', function () { pnl.showHelpPopup(this, true); });
            pnl.bindControlEvent(id, 'mouseout', '.pcp_formRow', function () { pnl.showHelpPopup(this, false); });
            pnl.bindControlEvent(id, 'mouseover', '.pcp_txtBtn', function () { this.style.backgroundColor = 'silver' });
            pnl.bindControlEvent(id, 'mouseout', '.pcp_txtBtn', function () { this.style.backgroundColor = 'gainsboro'; this.style.borderStyle = 'outset'; });
            pnl.bindControlEvent(id, 'mousedown', '.pcp_txtBtn', function () { this.style.borderStyle = 'inset' });
            pnl.bindControlEvent(id, 'mouseup', '.pcp_txtBtn', function () { this.style.borderStyle = 'outset' });
        }
    };
    var tabConfig = {
        m_bSaving: false,
        m_bPollingEnabled: false,
        loadConfigPanel: function () {
            console.log('loading config panel');
            pnl.loadPanelConfig(device, 'pcp_connectionPanel', 'pcpGetConfiguration', null, tabConfig.buildConfigPanel);
        },
        buildConfigPanel: function (c) {
            tabConfig.buildConnectionConfig();

            //if (typeof c !== 'undefined') cfg = c;
            //if (typeof cfg !== 'undefined')
            //    tabConfig.buildConnectionConfig();
            //else
            //    jQuery('#pcp_equipmentConfig').html('Reloading panel status');
        },
        buildConnectionConfig: function () {
            var obj = api.getDeviceObject(device);
            cfg.ip = api.getDeviceStateVariable(device, '', 'ip');
            cfg.OCPModel = api.getDeviceStateVariable(device, 'urn:rstrouse-com:serviceId:PoolController1', 'OCPModel');
            cfg.userName = api.getDeviceStateVariable(device, 'urn:rstrouse-com:serviceId:PoolController1', 'userName');
            cfg.password = api.getDeviceStateVariable(device, 'urn:rstrouse-com:serviceId:PoolController1', 'password');
            cfg.logLevel = api.getDeviceStateVariable(device, 'urn:rstrouse-com:serviceId:PoolController1', 'logLevel');
            cfg.childrenSameRoom = parseInt(api.getDeviceStateVariable(device, 'urn:micasaverde-com:serviceId:HaDevice1', 'ChildrenSameRoom'), 10) === 1;
            var html = '<table><tbody>';
            html += pnl.createDropdownRow('pcp_logLevel', 'Log Level', cfg.logLevel, [{ text:'Error', value: 0 }, { text:'Info', value:20 }, { text:'Verbose', value: 50 }, { text:'Debug', value: 70 }], {
                'data-bind': 'logLevel',
                helpText: 'Choose a logging level for the Luup Log.  Under most circumstances this should be set to error which only when an error occurs.'
                    + '<div><span style="font-weight:bold;font-syle:italic;">Error:</span><span>Only writes to the log on error.</span></div>'
                    + '<div><span style="font-weight:bold;font-syle:italic;">Info:</span><span>Writes errors and important events to the log.</span></div>'
                    + '<div><span style="font-weight:bold;font-syle:italic;">Verbose:</span><span>Writes errors, important events, and data exchanges to the log.</span></div>'
                    + '<div><span style="font-weight:bold;font-syle:italic;">Debug:</span><span>Writes additonal debugging information to the log.</span></div>'
            });
            console.log(cfg);
            html += pnl.createCheckboxRow('pcp_ChildDevicesSameRoom', 'Keep Equipment Together', cfg.childrenSameRoom,
                { 'data-bind': 'childrenSameRoom', helpText: 'Check this so that the equipment devices are created in the same room as the parent device.' });
            html += pnl.createInputRow('pcp_ipAddress', 'poolController IP Address', obj.ip,
                { 'data-bind': 'ipAddress', style: "width:450px;", helpText: 'Enter the IP address for your NodeJS poolController server.  You should set a DHCP reservation on your router for the device.  That way the ip address will remain the same.  See the manual for your router for instructions.' });
            html += pnl.createInputRow('pcp_userName', 'poolController Username', cfg.userName,
                { 'data-bind': 'userName', style: "width:250px;", helpText: 'Enter the username for connecting to your NodeJS poolController server.  The default is <span style="font-weight:bold;font-syle:italic;">empty.</span>' });
            html += pnl.createInputRow('pcp_password', 'poolController Password', cfg.password,
                { 'data-bind': 'password', style: "width:250px;", helpText: 'Enter the password for connecting to your NodeJS poolController server.  The default is <span style="font-weight:bold;font-syle:italic;">empty.</span>' });
            html += '</tbody></table>';
            pnl.setPanelHtml('#pcp_connectionPanel', html);
        },
        saveConfigChanges: function () {
            var o = pnl.fromWindow('div.pcp_cfgPanel');
            var obj = api.getDeviceObject(device);
            var rebuildChildren = 0;
            tabConfig.m_bSaving = true;
            cfg.childrenSameRoom = parseInt(api.getDeviceState(device, 'urn:micasaverde-com:serviceId:HaDevice1', 'ChildrenSameRoom'), 10) === 1;
            if (o.ipAddress !== obj.ip || o.devMode !== cfg.devMode || o.userName !== cfg.userName || o.password !== cfg.password) rebuildChildren = 1;
            //api.setDeviceStatePersistent(device, 'urn:micasaverde-com:serviceId:HaDevice1', 'ChildrenSameRoom', o.childrenSameRoom ? "1" : "0");

            // Perform the save.
            //api.setDeviceStatePersistent(device, 'urn:rstrouse-com:serviceId:PoolController1', 'Username', o.userName);
            //api.setDeviceStatePersistent(device, 'urn:rstrouse-com:serviceId:PoolController1', 'Password', o.password);
            //pnl.enablePanelControls('#pcp_configPanel', false);
            console.log(o);
            dlgMgr.showStatusDialog({
                title: "Saving Configuration...",
                width: '350px',
                message: 'Saving Configuration... Please wait!'
            });
            try {
                new Ajax.Request(api.getSendCommandURL() + '/data_request', {
                    method: "GET",
                    parameters: {
                        id: "lr_pcpSetConfiguration",
                        rand: Math.random(),
                        data: JSON.stringify(o).replace(/ /g, '%20'),
                        output_format: "json"
                    },
                    onSuccess: function (response) {
                        if (jQuery('#pcp_btnSaveChanges').length > 0)
                            jQuery('#pcp_btnSaveChanges').hide();
                        dlgMgr.closeDialog();
                        tabConfig.m_bSaving = false;
                    },
                    onFailure: function () {
                        dlgMgr.closeDialog();
                        dlgMgr.showMessageDialog({
                            title: 'Error',
                            width: '350px',
                            message: 'Error saving configuration'
                        });
                    }
                });
            }
            catch (err) { console.log(err); }
        }
    };
    /*---------------------------------------------------------
	* Tab Entry Points
	* -------------------------------------------------------*/
    function showConfigureTab() {
        device = api.getCpanelDeviceId();
        var html = pnl.createConfigWindow('Equipment Panel Configuration');
        //html += '<div id="pcp_connectionInfo">Loading...</div>';
        html += pnl.createConfigPanel('pcp_connectionPanel', 'NodeJS poolController Connection');
        html += '<input class="vBtn pull-right" type="button" id="pcp_btnSaveChanges" style="margin-top:4px;display:none;" value="Save Changes"/>';
        api.setCpanelContent(html);
        pnl.bindControlEvent('#pcp_btnSaveChanges', 'click', function () { tabConfig.saveConfigChanges(); });
        tabConfig.loadConfigPanel();
    }
    function init() {
        // Create all the styles for the configuration controls
        var gradFrom = '119d2d';
        var gradTo = '295982';
        var sStyle = '.pcp_modalTitle { cursor:pointer;width:100%;border-top-left-radius:4px;border-top-right-radius:4px;display:block;border:solid 1px silver;border-bottom:solid 3px orange;padding:4px;background-color:steelblue;}'
            + '.pcp_titleGradient {' + pnl.createGradient(gradFrom, gradTo) + 'color:white;font-weight:bold;}'
            + '.pcp_dialogShadow { box-shadow: 3px 3px 5px 6px rgba(0,1,1,0.4);}'
            + '.pcp_popupContainer { border-radius:7px; padding:4px; border:solid 1px silver; background-color:lightyellow; box-shadow: 2px 2px 3px 3px rgba(0,1,1,0.4);}'
            + '.pcp_dialogSubHeader {' + pnl.createGradient(gradFrom, gradTo) + 'color:white;font-weight:bold;}'
            + 'input.pcp_editField { border-radius:4px; font-size:inherit; font-family:OpenSansLight, helv, arial; border:solid 1px silver; color:gray; padding-left:2px; padding-right:2px;margin-top:2px;}'
            + 'select.pcp_editField { border-radius:4px; font-size:inherit; font-family:OpenSansLight, helv, arial; border:solid 1px silver; color:gray; padding-left:2px; padding-right:2px; margin-top:2px;}'
            + 'span.pcp_editField { font-size:inherit; font-family:OpenSansLight, helv, arial; }'
            + 'label.pcp_label { font-size:inherit;font-family:OpenSansLight, helv, arial; }'
            + 'table.pcp_dipSwitch { border:solid 1px black;padding:0px;border-collapse:separate;border-spacing:0px;box-sizing:border-box; }'
            + 'td.pcp_dipSwitch { background-color:black;border:solid 1px white;height:100%;}'
            + 'div.pcp_dipSwitchText { padding-left:2px;padding-right:2px;font-size:10px;font-family:arial,helv; }'
            + '.pcp_cfgTitle { font-family:arial, helv;font-size:22px; }'
            + '.pcp_cfgPanel { border:solid 1px gray;margin-top:7px;display:inline-block;width:100%;}'
            + '.pcp_cfgPanelContent { padding:4px;font-family:OpenSansLight, helv, arial;font-size:inherit; }'
            + 'table.pcp_dipSwitch {border:solid 1px black;padding:0px;border-collapse:separate;border-spacing:0px;font-family:arial,helv;}'
            + 'td.pcp_dipSwitch {background-color:black;border:solid 1px white;}'
            + 'div.pcp_dipSwitchText {padding-left:2px;padding-right:2px;}'
            + 'div.pcp_dipSwitchThumb { border:solid 1px gray;vertical-align:bottom;background-color:white;height:7px;width:8px;display:block;position:relative;border-radius:1px;box-sizing:border-box;margin-top:2px;margin-bottom:2px; }'
            + '.pcp_dipSwitchOn {vertical-align:top;}'
            + '.pcp_dipSwitchOff {vertical-align:bottom;}'
            + '.pcp_txtBtn {box-sizing:border-box;width:22px;height:22px;border-radius:7px;cursor:pointer;border:outset 2px;padding:0px;display:inline-block;text-align:center;vertical-align:middle;padding-bottom:7px;background-color:gainsboro;}'
            + '.pcp_txtBtnText {box-sizing:border-box;vertical-align:top;display:inline-block;height:auto;font-weight:bold;font-family:helv, Arial;margin-top:-1px;}';
        if (typeof (jQuery) === 'undefined')
            console.log('JQuery is not running in this browser');
        else {
            console.log('Running jQuery Version:' + jQuery.fn.jquery);
        }
        try {
            jQuery('<style>')
                .attr('type', 'text/css')
                .html(sStyle)
                .appendTo("head");
        }
        catch (err) {
            console.log('JQuery Create Element Failed: Using pure javascript');
            var el = document.createElement('style');
            el.type = 'text/css';
            el.appendChild(document.createTextNode(sStyle));
            document.getElementsByTagName('head')[0].appendChild(el);
        }

    }
    var module = { init: init, showConfigureTab: showConfigureTab };
    init();
    return module;
})(api);

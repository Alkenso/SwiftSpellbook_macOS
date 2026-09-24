//  MIT License
//
//  Copyright (c) 2022 Alkenso (Vladimir Vashurkin)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import EndpointSecurity
import Foundation

extension es_event_type_t: @retroactive Decodable {}
extension es_event_type_t: @retroactive Encodable {}

extension es_auth_result_t: @retroactive Decodable {}
extension es_auth_result_t: @retroactive Encodable {}

extension es_action_type_t: @retroactive Decodable {}
extension es_action_type_t: @retroactive Encodable {}

extension es_result_type_t: @retroactive Decodable {}
extension es_result_type_t: @retroactive Encodable {}

extension es_return_t: @retroactive Decodable {}
extension es_return_t: @retroactive Encodable {}

extension es_respond_result_t: @retroactive Decodable {}
extension es_respond_result_t: @retroactive Encodable {}

extension es_new_client_result_t: @retroactive Decodable {}
extension es_new_client_result_t: @retroactive Encodable {}

extension es_clear_cache_result_t: @retroactive Decodable {}
extension es_clear_cache_result_t: @retroactive Encodable {}

extension es_proc_check_type_t: @retroactive Decodable {}
extension es_proc_check_type_t: @retroactive Encodable {}

extension es_proc_suspend_resume_type_t: @retroactive Decodable {}
extension es_proc_suspend_resume_type_t: @retroactive Encodable {}

extension es_set_or_clear_t: @retroactive Decodable {}
extension es_set_or_clear_t: @retroactive Encodable {}

extension es_mute_path_type_t: @retroactive Decodable {}
extension es_mute_path_type_t: @retroactive Encodable {}

extension es_mute_inversion_type_t: @retroactive Decodable {}
extension es_mute_inversion_type_t: @retroactive Encodable {}

extension es_mute_inverted_return_t: @retroactive Decodable {}
extension es_mute_inverted_return_t: @retroactive Encodable {}

extension es_btm_item_type_t: @retroactive Decodable {}
extension es_btm_item_type_t: @retroactive Encodable {}

extension es_touchid_mode_t: @retroactive Decodable {}
extension es_touchid_mode_t: @retroactive Encodable {}

extension es_auto_unlock_type_t: @retroactive Decodable {}
extension es_auto_unlock_type_t: @retroactive Encodable {}

extension es_openssh_login_result_type_t: @retroactive Decodable {}
extension es_openssh_login_result_type_t: @retroactive Encodable {}

extension es_address_type_t: @retroactive Decodable {}
extension es_address_type_t: @retroactive Encodable {}

extension es_profile_source_t: @retroactive Decodable {}
extension es_profile_source_t: @retroactive Encodable {}

extension es_sudo_plugin_type_t: @retroactive Decodable {}
extension es_sudo_plugin_type_t: @retroactive Encodable {}

extension es_authorization_rule_class_t: @retroactive Decodable {}
extension es_authorization_rule_class_t: @retroactive Encodable {}

extension es_od_account_type_t: @retroactive Decodable {}
extension es_od_account_type_t: @retroactive Encodable {}

extension es_od_record_type_t: @retroactive Decodable {}
extension es_od_record_type_t: @retroactive Encodable {}

extension es_xpc_domain_type_t: @retroactive Decodable {}
extension es_xpc_domain_type_t: @retroactive Encodable {}

extension es_get_task_type_t: @retroactive Decodable {}
extension es_get_task_type_t: @retroactive Encodable {}

extension es_mount_disposition_t: @retroactive Decodable {}
extension es_mount_disposition_t: @retroactive Encodable {}

extension es_cs_validation_category_t: @retroactive Decodable {}
extension es_cs_validation_category_t: @retroactive Encodable {}

extension es_tcc_event_type_t: @retroactive Decodable {}
extension es_tcc_event_type_t: @retroactive Encodable {}

extension es_tcc_identity_type_t: @retroactive Decodable {}
extension es_tcc_identity_type_t: @retroactive Encodable {}

extension es_tcc_authorization_right_t: @retroactive Decodable {}
extension es_tcc_authorization_right_t: @retroactive Encodable {}

extension es_tcc_authorization_reason_t: @retroactive Decodable {}
extension es_tcc_authorization_reason_t: @retroactive Encodable {}

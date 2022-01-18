# frozen_string_literal: true

require_relative "cops/specify_low_queue_in_migration"
require_relative "cops/active-record/update_attribute"
require_relative "cops/active-record/no_active_record_rollback_raise"
require_relative "cops/active-record/no_transaction_on_add_index_migration"
require_relative "cops/active-record/save_bang"
require_relative "cops/check_path_documented"
require_relative "cops/postgresql/no_between"
require_relative "cops/postgresql/no_set"
require_relative "cops/no_timeout_usage"
require_relative "cops/no_undefined_variable_usage"

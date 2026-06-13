# Gate the Mission Control Jobs dashboard on a drift admin session and turn off the
# engine's built-in HTTP Basic auth. See app/controllers/admin/base_controller.rb.
#
# Set the module attributes directly (not config.mission_control.jobs.*): the engine
# copies its config into these attributes in its own initializer, which runs before
# config/initializers, so the config proxy would be read too early. These attributes are
# read lazily (base controller at class-load, auth flag per-request), so this sticks.
MissionControl::Jobs.base_controller_class = "Admin::BaseController"
MissionControl::Jobs.http_basic_auth_enabled = false

//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <flutter_blue_plus_winrt/flutter_blue_plus_plugin.h>
#include <flutter_timezone/flutter_timezone_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FlutterBluePlusPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterBluePlusPlugin"));
  FlutterTimezonePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTimezonePluginCApi"));
}

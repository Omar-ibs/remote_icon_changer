package com.omaribrahim.app_icon_switcher

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class AppIconSwitcherPluginTest {
    @Test
    fun onMethodCall_isSupported_returnsTrue() {
        val plugin = AppIconSwitcherPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("isSupported", null), mockResult)
        Mockito.verify(mockResult).success(true)
    }
}

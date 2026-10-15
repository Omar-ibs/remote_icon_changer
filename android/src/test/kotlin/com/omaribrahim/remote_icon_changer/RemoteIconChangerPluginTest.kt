package com.omaribrahim.remote_icon_changer

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class RemoteIconChangerPluginTest {
    @Test
    fun onMethodCall_isSupported_returnsTrue() {
        val plugin = RemoteIconChangerPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("isSupported", null), mockResult)
        Mockito.verify(mockResult).success(true)
    }
}

package com.example.caracterizacao_android

import android.content.ClipData
import android.content.Intent
import android.view.MotionEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val NATIVE_TOUCH_CHANNEL =
            "caracterizacao_android/native_touch"

        private const val FILE_EXPORT_CHANNEL =
            "caracterizacao_android/file_export"
    }

    private var nativeTouchEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        // ============================================================
        // CANAL DE EVENTOS DE TOQUE NATIVO
        // ============================================================

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_TOUCH_CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink
                ) {
                    nativeTouchEventSink = events
                }

                override fun onCancel(
                    arguments: Any?
                ) {
                    nativeTouchEventSink = null
                }
            }
        )

        // ============================================================
        // CANAL DE EXPORTAÇÃO / COMPARTILHAMENTO DO CSV
        // ============================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_EXPORT_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "openCsv" -> {

                    val fileName =
                        call.argument<String>("fileName")
                            ?: "coleta.csv"

                    val content =
                        call.argument<String>("content")
                            ?: ""

                    openCsv(
                        fileName = fileName,
                        content = content,
                        result = result
                    )
                }

                "shareCsv" -> {

                    val fileName =
                        call.argument<String>("fileName")
                            ?: "coleta.csv"

                    val content =
                        call.argument<String>("content")
                            ?: ""

                    shareCsv(
                        fileName = fileName,
                        content = content,
                        result = result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ================================================================
    // CAPTURA DOS EVENTOS DE TOQUE ANDROID
    // ================================================================

    override fun dispatchTouchEvent(
        event: MotionEvent
    ): Boolean {

        sendNativeTouchEvent(event)

        return super.dispatchTouchEvent(event)
    }

    private fun sendNativeTouchEvent(
        event: MotionEvent
    ) {
        val sink = nativeTouchEventSink
            ?: return

        try {

            val pointers =
                mutableListOf<Map<String, Any>>()

            for (index in 0 until event.pointerCount) {

                val pointer =
                    mapOf(
                        "pointerIndex" to index,
                        "pointerId" to event.getPointerId(index),
                        "x" to event.getX(index),
                        "y" to event.getY(index),
                        "pressure" to event.getPressure(index),
                        "size" to event.getSize(index),
                        "touchMajor" to event.getTouchMajor(index),
                        "touchMinor" to event.getTouchMinor(index),
                        "toolMajor" to event.getToolMajor(index),
                        "toolMinor" to event.getToolMinor(index),
                        "toolType" to event.getToolType(index)
                    )

                pointers.add(pointer)
            }

            val eventData =
                mapOf(
                    "action" to event.action,
                    "actionMasked" to event.actionMasked,
                    "actionIndex" to event.actionIndex,
                    "actionName" to getActionName(
                        event.actionMasked
                    ),
                    "eventTimeMs" to event.eventTime,
                    "downTimeMs" to event.downTime,
                    "pointerCount" to event.pointerCount,
                    "historySize" to event.historySize,
                    "deviceId" to event.deviceId,
                    "source" to event.source,
                    "pointers" to pointers
                )

            sink.success(eventData)

        } catch (exception: Exception) {

            android.util.Log.e(
                "NativeTouch",
                "Erro ao enviar evento de toque",
                exception
            )
        }
    }

    // ================================================================
    // NOME DA AÇÃO DO MOTION EVENT
    // ================================================================

    private fun getActionName(
        actionMasked: Int
    ): String {

        return when (actionMasked) {

            MotionEvent.ACTION_DOWN ->
                "DOWN"

            MotionEvent.ACTION_UP ->
                "UP"

            MotionEvent.ACTION_MOVE ->
                "MOVE"

            MotionEvent.ACTION_CANCEL ->
                "CANCEL"

            MotionEvent.ACTION_POINTER_DOWN ->
                "POINTER_DOWN"

            MotionEvent.ACTION_POINTER_UP ->
                "POINTER_UP"

            MotionEvent.ACTION_OUTSIDE ->
                "OUTSIDE"

            MotionEvent.ACTION_HOVER_MOVE ->
                "HOVER_MOVE"

            MotionEvent.ACTION_SCROLL ->
                "SCROLL"

            else ->
                "OTHER"
        }
    }

    // ================================================================
    // ABRIR CSV
    // ================================================================

    private fun openCsv(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        try {

            val safeFileName =
                File(fileName).name

            /*
             * O arquivo é colocado somente no cache temporário
             * do aplicativo.
             *
             * Isso NÃO significa salvar a coleta em Downloads.
             * É apenas o arquivo temporário que será entregue
             * ao Android para outro aplicativo abrir.
             */
            val temporaryFile =
                File(
                    cacheDir,
                    safeFileName
                )

            temporaryFile.writeText(
                content,
                Charsets.UTF_8
            )

            val authority =
                "${applicationContext.packageName}.fileprovider"

            val contentUri =
                FileProvider.getUriForFile(
                    this,
                    authority,
                    temporaryFile
                )

            val openIntent =
                Intent(
                    Intent.ACTION_VIEW
                ).apply {

                    setDataAndType(
                        contentUri,
                        "text/csv"
                    )

                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )

                    clipData =
                        ClipData.newRawUri(
                            "CSV",
                            contentUri
                        )
                }

            val chooser =
                Intent.createChooser(
                    openIntent,
                    "Abrir CSV com..."
                )

            chooser.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            startActivity(chooser)

            result.success(true)

        } catch (exception: Exception) {

            android.util.Log.e(
                "CsvExport",
                "Erro ao abrir CSV",
                exception
            )

            result.error(
                "OPEN_FAILED",
                exception.message
                    ?: "Não foi possível abrir o CSV.",
                null
            )
        }
    }

    // ================================================================
    // COMPARTILHAR CSV
    // ================================================================

    private fun shareCsv(
        fileName: String,
        content: String,
        result: MethodChannel.Result
    ) {
        try {

            val safeFileName =
                File(fileName).name

            /*
             * Novamente, o arquivo fica apenas no cache temporário.
             */
            val temporaryFile =
                File(
                    cacheDir,
                    safeFileName
                )

            temporaryFile.writeText(
                content,
                Charsets.UTF_8
            )

            val authority =
                "${applicationContext.packageName}.fileprovider"

            val contentUri =
                FileProvider.getUriForFile(
                    this,
                    authority,
                    temporaryFile
                )

            val shareIntent =
                Intent(
                    Intent.ACTION_SEND
                ).apply {

                    type = "text/csv"

                    putExtra(
                        Intent.EXTRA_STREAM,
                        contentUri
                    )

                    putExtra(
                        Intent.EXTRA_TITLE,
                        safeFileName
                    )

                    addFlags(
                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )

                    clipData =
                        ClipData.newRawUri(
                            "CSV",
                            contentUri
                        )
                }

            val chooser =
                Intent.createChooser(
                    shareIntent,
                    "Compartilhar CSV"
                )

            chooser.addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )

            startActivity(chooser)

            result.success(true)

        } catch (exception: Exception) {

            android.util.Log.e(
                "CsvExport",
                "Erro ao compartilhar CSV",
                exception
            )

            result.error(
                "SHARE_FAILED",
                exception.message
                    ?: "Não foi possível compartilhar o CSV.",
                null
            )
        }
    }
}
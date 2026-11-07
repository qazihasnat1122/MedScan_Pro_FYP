package com.example.medscan_mobile

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.medscan.pro/document_picker"
    private val PICK_PDF_REQUEST = 9401
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDevApiKey" -> {
                    try {
                        val key = getString(R.string.medscan_dev_gemini_key)
                        result.success(key)
                    } catch (_: Exception) {
                        result.success("")
                    }
                }
                "getMapboxAccessToken" -> {
                    try {
                        val token = getString(R.string.medscan_dev_mapbox_token)
                        result.success(token)
                    } catch (_: Exception) {
                        result.success("")
                    }
                }
                "compressImageForAi" -> {
                    val filePath = call.argument<String>("path")
                    val maxDim = call.argument<Int>("maxDimension") ?: 1400
                    val quality = call.argument<Int>("quality") ?: 80
                    if (filePath.isNullOrBlank()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    try {
                        val compressed = compressImageFile(File(filePath), maxDim, quality)
                        result.success(compressed.absolutePath)
                    } catch (_: Exception) {
                        result.success(filePath)
                    }
                }
                "pickPdf" -> {
                    if (pendingResult != null) {
                        result.error("ALREADY_ACTIVE", "A document picker request is already active.", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/pdf"
                    }
                    try {
                        startActivityForResult(intent, PICK_PDF_REQUEST)
                    } catch (e: Exception) {
                        pendingResult = null
                        result.error("PICKER_ERROR", "Unable to open document picker: ${e.message}", null)
                    }
                }
                "renderPdfPages" -> {
                    val filePath = call.argument<String>("path")
                    val maxPages = call.argument<Int>("maxPages") ?: 5
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "PDF file path is required.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val rendered = renderPdfFile(File(filePath), maxPages)
                        result.success(rendered)
                    } catch (e: Exception) {
                        result.error("CORRUPT_PDF", "Unable to read or render PDF: ${e.message}", null)
                    }
                }
                "launchExternalUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val parsedUri = Uri.parse(uriString)
                        val action = if (parsedUri.scheme.equals("tel", ignoreCase = true)) {
                            Intent.ACTION_DIAL
                        } else {
                            Intent.ACTION_VIEW
                        }
                        val intent = Intent(action, parsedUri).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun compressImageFile(sourceFile: File, maxDimension: Int, quality: Int): File {
        if (!sourceFile.exists() || sourceFile.length() <= 350 * 1024L) {
            return sourceFile
        }
        val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(sourceFile.absolutePath, boundsOpts)
        val srcW = boundsOpts.outWidth
        val srcH = boundsOpts.outHeight
        if (srcW <= 0 || srcH <= 0) return sourceFile

        var sampleSize = 1
        while (max(srcW / sampleSize, srcH / sampleSize) > maxDimension * 2) {
            sampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        val decoded = BitmapFactory.decodeFile(sourceFile.absolutePath, decodeOpts) ?: return sourceFile

        val maxSide = max(decoded.width, decoded.height)
        val finalBitmap = if (maxSide > maxDimension) {
            val ratio = maxDimension.toFloat() / maxSide.toFloat()
            val targetW = (decoded.width * ratio).roundToInt().coerceAtLeast(1)
            val targetH = (decoded.height * ratio).roundToInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(decoded, targetW, targetH, true)
            if (scaled != decoded) decoded.recycle()
            scaled
        } else {
            decoded
        }

        val outFile = File(cacheDir, "ai_opt_${System.currentTimeMillis()}.jpg")
        FileOutputStream(outFile).use { out ->
            finalBitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(50, 95), out)
        }
        finalBitmap.recycle()
        return if (outFile.exists() && outFile.length() > 0L) outFile else sourceFile
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_PDF_REQUEST) {
            val callback = pendingResult
            pendingResult = null
            if (callback == null) return

            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                callback.success(null)
                return
            }

            val uri: Uri = data.data!!
            try {
                val fileName = queryFileName(uri) ?: "prescription_${System.currentTimeMillis()}.pdf"
                val destFile = File(cacheDir, "rx_${System.currentTimeMillis()}_${fileName.replace(Regex("[^a-zA-Z0-9._-]"), "_")}")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                } ?: throw IllegalStateException("Cannot open selected file stream.")

                if (!destFile.exists() || destFile.length() == 0L) {
                    destFile.delete()
                    callback.error("EMPTY_FILE", "The selected PDF file is empty.", null)
                    return
                }

                val rendered = renderPdfFile(destFile, 5)
                callback.success(rendered)
            } catch (e: Exception) {
                callback.error("CORRUPT_PDF", "The selected PDF could not be opened or is corrupted: ${e.message}", null)
            }
        }
    }

    private fun queryFileName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                return cursor.getString(nameIndex)
            }
        }
        return null
    }

    private fun renderPdfFile(pdfFile: File, maxPages: Int): Map<String, Any> {
        if (!pdfFile.exists() || pdfFile.length() < 5L) {
            throw IllegalArgumentException("PDF file is empty or unreadable.")
        }
        val pfd = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(pfd)
        val pageCount = renderer.pageCount
        if (pageCount <= 0) {
            renderer.close()
            pfd.close()
            throw IllegalArgumentException("PDF has no pages.")
        }

        val pagePaths = mutableListOf<String>()
        val pagesToRender = minOf(pageCount, maxPages)
        for (i in 0 until pagesToRender) {
            val page = renderer.openPage(i)
            val scale = 2
            val width = (page.width * scale).coerceAtMost(1400)
            val height = (page.height * scale).coerceAtMost(1800)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            page.close()

            val pageFile = File(cacheDir, "${pdfFile.nameWithoutExtension}_page_${i + 1}.jpg")
            FileOutputStream(pageFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 82, out)
            }
            bitmap.recycle()
            pagePaths.add(pageFile.absolutePath)
        }
        renderer.close()
        pfd.close()

        return mapOf(
            "path" to pdfFile.absolutePath,
            "fileName" to pdfFile.name,
            "pageCount" to pageCount,
            "pagePaths" to pagePaths
        )
    }
}

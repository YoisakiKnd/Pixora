package io.github.yoisakiknd.pixora

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.URLConnection

class MainActivity : FlutterActivity() {
    private var pendingDirectoryResult: MethodChannel.Result? = null
    private var pendingLegacyCommit: PendingCommit? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighestRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDefaultLocation" -> result.success(
                    mapOf(
                        "kind" to "mediaStore",
                        "value" to "Pictures/Pixora",
                        "label" to "系统图片/Pixora",
                    ),
                )
                "pickDirectory" -> pickDirectory(result)
                "commitFile" -> {
                    @Suppress("UNCHECKED_CAST")
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("invalid_arguments", "下载目标参数无效", null)
                    } else {
                        commitFile(arguments, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingDirectoryResult != null) {
            result.error("picker_busy", "文件夹选择器正在使用", null)
            return
        }
        pendingDirectoryResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, DIRECTORY_REQUEST_CODE)
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != DIRECTORY_REQUEST_CODE) return
        val result = pendingDirectoryResult ?: return
        pendingDirectoryResult = null
        val treeUri = data?.data
        if (resultCode != RESULT_OK || treeUri == null) {
            result.success(null)
            return
        }
        try {
            val flags = data.flags and (
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
            contentResolver.takePersistableUriPermission(treeUri, flags)
            result.success(
                mapOf(
                    "value" to treeUri.toString(),
                    "label" to treeDisplayName(treeUri),
                ),
            )
        } catch (error: Exception) {
            result.error("directory_permission", error.message, null)
        }
    }

    private fun commitFile(
        arguments: Map<String, Any?>,
        result: MethodChannel.Result,
    ) {
        val kind = arguments["kind"] as? String
        if (
            kind == "mediaStore" &&
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            if (pendingLegacyCommit != null) {
                result.error("permission_busy", "正在请求存储权限", null)
                return
            }
            pendingLegacyCommit = PendingCommit(arguments, result)
            requestPermissions(
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                LEGACY_STORAGE_PERMISSION_REQUEST_CODE,
            )
            return
        }
        startCommit(arguments, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LEGACY_STORAGE_PERMISSION_REQUEST_CODE) return
        val pending = pendingLegacyCommit ?: return
        pendingLegacyCommit = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startCommit(pending.arguments, pending.result)
        } else {
            pending.result.error("storage_permission_denied", "未授予图片目录写入权限", null)
        }
    }

    private fun startCommit(
        arguments: Map<String, Any?>,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val sourcePath = requireArgument(arguments, "sourcePath")
                val kind = requireArgument(arguments, "kind")
                val root = requireArgument(arguments, "root")
                val fileName = requireArgument(arguments, "fileName")
                val relativeSegments = (arguments["relativeSegments"] as? List<*>)
                    ?.filterIsInstance<String>()
                    ?: emptyList()
                val committed = when (kind) {
                    "mediaStore" -> commitToMediaStore(
                        File(sourcePath),
                        relativeSegments,
                        fileName,
                    )
                    "androidTree" -> commitToDocumentTree(
                        File(sourcePath),
                        Uri.parse(root),
                        relativeSegments,
                        fileName,
                    )
                    else -> error("不支持的 Android 下载目标")
                }
                runOnUiThread { result.success(committed) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "commit_failed",
                        error.message ?: error.javaClass.simpleName,
                        null,
                    )
                }
            }
        }.start()
    }

    private fun commitToMediaStore(
        source: File,
        relativeSegments: List<String>,
        requestedName: String,
    ): Map<String, String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return commitToLegacyPictures(source, relativeSegments, requestedName)
        }
        val relativePath = buildString {
            append(Environment.DIRECTORY_PICTURES)
            append("/Pixora/")
            if (relativeSegments.isNotEmpty()) {
                append(relativeSegments.joinToString("/"))
                append('/')
            }
        }
        val collection = MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY,
        )
        val fileName = uniqueMediaStoreName(collection, relativePath, requestedName)
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType(fileName))
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(collection, values)
            ?: error("无法在系统图片目录创建文件")
        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: error("无法写入系统图片目录")
            contentResolver.update(
                uri,
                ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) },
                null,
                null,
            )
            return mapOf("fileName" to fileName, "uri" to uri.toString())
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun commitToLegacyPictures(
        source: File,
        relativeSegments: List<String>,
        requestedName: String,
    ): Map<String, String> {
        var directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "Pixora",
        )
        for (segment in relativeSegments) directory = File(directory, segment)
        directory.mkdirs()
        val target = uniqueFile(directory, requestedName)
        source.copyTo(target)
        return mapOf("fileName" to target.name, "uri" to Uri.fromFile(target).toString())
    }

    private fun commitToDocumentTree(
        source: File,
        treeUri: Uri,
        relativeSegments: List<String>,
        requestedName: String,
    ): Map<String, String> {
        var parent = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        for (segment in relativeSegments) {
            parent = findChild(treeUri, parent, segment, DIRECTORY_MIME)
                ?: DocumentsContract.createDocument(
                    contentResolver,
                    parent,
                    DIRECTORY_MIME,
                    segment,
                )
                ?: error("无法创建分类目录 $segment")
        }
        val fileName = uniqueDocumentName(treeUri, parent, requestedName)
        val fileUri = DocumentsContract.createDocument(
            contentResolver,
            parent,
            mimeType(fileName),
            fileName,
        ) ?: error("无法在所选目录创建文件")
        try {
            contentResolver.openOutputStream(fileUri, "w")?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: error("无法写入所选目录")
            return mapOf("fileName" to fileName, "uri" to fileUri.toString())
        } catch (error: Exception) {
            DocumentsContract.deleteDocument(contentResolver, fileUri)
            throw error
        }
    }

    private fun uniqueMediaStoreName(
        collection: Uri,
        relativePath: String,
        requestedName: String,
    ): String {
        var candidate = requestedName
        var index = 1
        while (
            contentResolver.query(
                collection,
                arrayOf(MediaStore.Images.Media._ID),
                "${MediaStore.Images.Media.DISPLAY_NAME}=? AND " +
                    "${MediaStore.Images.Media.RELATIVE_PATH}=?",
                arrayOf(candidate, relativePath),
                null,
            )?.use { it.moveToFirst() } == true
        ) {
            candidate = numberedName(requestedName, index++)
        }
        return candidate
    }

    private fun uniqueDocumentName(
        treeUri: Uri,
        parent: Uri,
        requestedName: String,
    ): String {
        var candidate = requestedName
        var index = 1
        while (findChild(treeUri, parent, candidate, null) != null) {
            candidate = numberedName(requestedName, index++)
        }
        return candidate
    }

    private fun uniqueFile(directory: File, requestedName: String): File {
        var candidate = File(directory, requestedName)
        var index = 1
        while (candidate.exists()) {
            candidate = File(directory, numberedName(requestedName, index++))
        }
        return candidate
    }

    private fun findChild(
        treeUri: Uri,
        parent: Uri,
        displayName: String,
        mime: String?,
    ): Uri? {
        val parentId = DocumentsContract.getDocumentId(parent)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            treeUri,
            parentId,
        )
        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        contentResolver.query(childrenUri, projection, null, null, null)?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            )
            val nameIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            )
            val mimeIndex = cursor.getColumnIndexOrThrow(
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            while (cursor.moveToNext()) {
                if (cursor.getString(nameIndex) != displayName) continue
                if (mime != null && cursor.getString(mimeIndex) != mime) continue
                return DocumentsContract.buildDocumentUriUsingTree(
                    treeUri,
                    cursor.getString(idIndex),
                )
            }
        }
        return null
    }

    private fun treeDisplayName(treeUri: Uri): String {
        val root = DocumentsContract.buildDocumentUriUsingTree(
            treeUri,
            DocumentsContract.getTreeDocumentId(treeUri),
        )
        contentResolver.query(
            root,
            arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return "自定义文件夹"
    }

    private fun mimeType(fileName: String): String =
        URLConnection.guessContentTypeFromName(fileName) ?: "image/jpeg"

    private fun numberedName(fileName: String, index: Int): String {
        val dot = fileName.lastIndexOf('.')
        if (dot <= 0) return "$fileName ($index)"
        return "${fileName.substring(0, dot)} ($index)${fileName.substring(dot)}"
    }

    private fun requireArgument(arguments: Map<String, Any?>, key: String): String =
        (arguments[key] as? String)?.takeIf { it.isNotEmpty() }
            ?: error("缺少参数 $key")

    private fun preferHighestRefreshRate() {
        val currentDisplay = windowManager.defaultDisplay
        val currentMode = currentDisplay.mode
        val preferredMode = currentDisplay.supportedModes
            .asSequence()
            .filter {
                it.physicalWidth == currentMode.physicalWidth &&
                    it.physicalHeight == currentMode.physicalHeight
            }
            .maxByOrNull { it.refreshRate }
            ?: return
        val attributes = window.attributes
        attributes.preferredDisplayModeId = preferredMode.modeId
        attributes.preferredRefreshRate = preferredMode.refreshRate
        window.attributes = attributes
    }

    private data class PendingCommit(
        val arguments: Map<String, Any?>,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val DOWNLOAD_CHANNEL = "io.github.yoisakiknd.pixora/downloads"
        private const val DIRECTORY_REQUEST_CODE = 4102
        private const val LEGACY_STORAGE_PERMISSION_REQUEST_CODE = 4103
        private const val DIRECTORY_MIME = "vnd.android.document/directory"
    }
}

package com.resq.app.crypto

import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

object MeshCrypto {
    private const val PREFIX = "RESQENC1:"
    private const val KEY_SEED = "resq-link-offline-mesh-shared-key-v1"
    private const val IV_LENGTH_BYTES = 12
    private const val TAG_LENGTH_BITS = 128

    private val random = SecureRandom()

    fun encrypt(plainText: String): String {
        if (plainText.isBlank() || plainText.startsWith(PREFIX)) return plainText

        val iv = ByteArray(IV_LENGTH_BYTES)
        random.nextBytes(iv)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keySpec(), GCMParameterSpec(TAG_LENGTH_BITS, iv))
        val encrypted = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))

        return PREFIX +
            Base64.encodeToString(iv, Base64.NO_WRAP) +
            "." +
            Base64.encodeToString(encrypted, Base64.NO_WRAP)
    }

    fun decrypt(payload: String): String {
        if (!payload.startsWith(PREFIX)) return payload

        return try {
            val body = payload.removePrefix(PREFIX)
            val parts = body.split(".", limit = 2)
            if (parts.size != 2) return payload

            val iv = Base64.decode(parts[0], Base64.NO_WRAP)
            val encrypted = Base64.decode(parts[1], Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, keySpec(), GCMParameterSpec(TAG_LENGTH_BITS, iv))
            String(cipher.doFinal(encrypted), Charsets.UTF_8)
        } catch (_: Exception) {
            payload
        }
    }

    private fun keySpec(): SecretKeySpec {
        val keyBytes = MessageDigest.getInstance("SHA-256")
            .digest(KEY_SEED.toByteArray(Charsets.UTF_8))
        return SecretKeySpec(keyBytes, "AES")
    }
}

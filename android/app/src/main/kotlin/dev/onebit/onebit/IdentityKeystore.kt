package dev.onebit.onebit

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Hardware-protected vault for OneBit identity seeds.
 *
 * The 32-byte Ed25519 and X25519 seeds never touch plaintext storage: each is
 * wrapped with AES-256-GCM using a key that lives only inside the Android
 * Keystore (`onebit_seed_wrap`), and only the [wrapped bytes + IV] are kept
 * in SharedPreferences. Wrapping keys are hardware-backed on devices that
 * support StrongBox / TEE keystore.
 *
 * Key material is returned to Dart only for the lifetime of a single
 * signing or key-agreement call, per the KeystoreKeyBridge contract.
 */
class IdentityKeystore(context: Context) {

    private val prefs =
        context.getSharedPreferences("onebit_identity", Context.MODE_PRIVATE)
    private val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    /** Encrypts [seedB64] under the Keystore AES key and persists it. */
    @Synchronized
    fun storeSeed(alias: String, seedB64: String): Boolean {
        val seed = Base64.decode(seedB64, Base64.NO_WRAP)
        val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, aesKey())
        val cipherText = cipher.doFinal(seed)
        val iv = cipher.iv
        val wrapped = ByteArray(iv.size + cipherText.size)
        System.arraycopy(iv, 0, wrapped, 0, iv.size)
        System.arraycopy(cipherText, 0, wrapped, iv.size, cipherText.size)
        prefs.edit().putString(alias, Base64.encodeToString(wrapped, Base64.NO_WRAP)).apply()
        return true
    }

    /** Unwraps the seed stored under [alias], or `null` when absent. */
    @Synchronized
    fun loadSeed(alias: String): String? {
        val wrappedB64 = prefs.getString(alias, null) ?: return null
        val wrapped = Base64.decode(wrappedB64, Base64.NO_WRAP)
        if (wrapped.size < IV_LENGTH) return null
        val iv = wrapped.copyOfRange(0, IV_LENGTH)
        val cipherText = wrapped.copyOfRange(IV_LENGTH, wrapped.size)
        val cipher = Cipher.getInstance(AES_GCM_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, aesKey(), GCMParameterSpec(TAG_BITS, iv))
        val seed = cipher.doFinal(cipherText)
        return Base64.encodeToString(seed, Base64.NO_WRAP)
    }

    fun hasIdentity(alias: String): Boolean = prefs.contains(alias)

    /** Removes the wrapped seed; returns false when the alias did not exist. */
    fun deleteIdentity(alias: String): Boolean {
        if (!prefs.contains(alias)) return false
        prefs.edit().remove(alias).apply()
        return true
    }

    private fun aesKey(): SecretKey {
        keyStore.getKey(KEY_ALIAS, null)?.let { return it as SecretKey }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            ANDROID_KEYSTORE,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "onebit_seed_wrap"
        private const val AES_GCM_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_LENGTH = 12
        private const val TAG_BITS = 128
    }
}

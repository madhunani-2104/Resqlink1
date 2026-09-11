package com.resq.app.mesh

import android.content.Context
import java.util.UUID

class MeshNodeIdentity(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    val nodeId: String
        get() {
            val existing = preferences.getString(NODE_ID_KEY, null)
            if (existing != null) return existing

            val generated = "RESQ-${UUID.randomUUID()}"
            preferences.edit().putString(NODE_ID_KEY, generated).apply()
            return generated
        }

    companion object {
        private const val PREFERENCES = "resq_mesh_identity"
        private const val NODE_ID_KEY = "node_id"
    }
}

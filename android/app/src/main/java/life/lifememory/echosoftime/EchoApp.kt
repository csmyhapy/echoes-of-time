package life.lifememory.echosoftime

import android.app.Application
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.data.EchoDatabase
import life.lifememory.echosoftime.data.EchoRepository

class EchoApp : Application() {

    lateinit var repo: EchoRepository
        private set
    lateinit var purchase: PurchaseManager
        private set

    override fun onCreate() {
        super.onCreate()
        val dao = EchoDatabase.get(this).dao()
        repo = EchoRepository(this, dao)
        purchase = PurchaseManager(this)
        purchase.start()
    }
}

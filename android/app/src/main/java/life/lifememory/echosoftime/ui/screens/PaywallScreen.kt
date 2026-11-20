package life.lifememory.echosoftime.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import life.lifememory.echosoftime.R
import life.lifememory.echosoftime.billing.EntitlementTier
import life.lifememory.echosoftime.billing.ProductID
import life.lifememory.echosoftime.billing.PurchaseManager
import life.lifememory.echosoftime.ui.components.stringRes

@Composable
fun PaywallScreen(purchase: PurchaseManager, onBack: () -> Unit) {
    val context = LocalContext.current
    val tier by purchase.tier.collectAsState()

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(stringRes(R.string.paywall_title), fontWeight = FontWeight.Bold, fontSize = 20.sp, modifier = Modifier.weight(1f))
            IconButton(onClick = onBack) { Icon(Icons.Filled.Close, contentDescription = null) }
        }
        Spacer(Modifier.height(22.dp))

        // header
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.WorkspacePremium, contentDescription = null, tint = Color.White)
            }
            Text(stringRes(R.string.paywall_heading), fontSize = 20.sp, fontWeight = FontWeight.Bold)
            Text(stringRes(R.string.paywall_subtitle), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.height(22.dp))

        PlanCard(
            title = stringRes(R.string.paywall_plan_pro_title),
            badge = stringRes(R.string.paywall_plan_pro_badge),
            features = listOf(
                stringRes(R.string.paywall_plan_pro_f1),
                stringRes(R.string.paywall_plan_pro_f2),
                stringRes(R.string.paywall_plan_pro_f3),
            ),
            highlighted = true,
        )
        Spacer(Modifier.height(14.dp))
        PlanCard(
            title = stringRes(R.string.paywall_plan_basic_title),
            badge = null,
            features = listOf(
                stringRes(R.string.paywall_plan_basic_f1),
                stringRes(R.string.paywall_plan_basic_f2),
                stringRes(R.string.paywall_plan_basic_f3),
            ),
            highlighted = false,
        )
        Spacer(Modifier.height(22.dp))

        when (tier) {
            EntitlementTier.PRO -> {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f))
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(10.dp))
                    Text(stringRes(R.string.paywall_pro_unlocked), fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                }
            }
            EntitlementTier.BASIC -> {
                BuyButton(
                    title = stringRes(R.string.paywall_buy_upgrade),
                    price = priceOf(purchase, ProductID.UPGRADE_FULL),
                    primary = true,
                    onClick = { purchase.purchase(context as android.app.Activity, ProductID.UPGRADE_FULL) },
                )
            }
            EntitlementTier.UNPAID -> {
                BuyButton(
                    title = stringRes(R.string.paywall_buy_full),
                    price = priceOf(purchase, ProductID.FULL),
                    primary = true,
                    onClick = { purchase.purchase(context as android.app.Activity, ProductID.FULL) },
                )
                Spacer(Modifier.height(12.dp))
                BuyButton(
                    title = stringRes(R.string.paywall_buy_basic),
                    price = priceOf(purchase, ProductID.BASIC),
                    primary = false,
                    onClick = { purchase.purchase(context as android.app.Activity, ProductID.BASIC) },
                )
            }
        }

        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            TextButton(onClick = { purchase.restore() }) {
                Text(stringRes(R.string.paywall_restore), color = MaterialTheme.colorScheme.primary)
            }
        }
    }
}

private fun priceOf(purchase: PurchaseManager, id: String): String =
    purchase.productDetails(id)
        ?.oneTimePurchaseOfferDetails
        ?.formattedPrice ?: ""

@Composable
private fun PlanCard(title: String, badge: String?, features: List<String>, highlighted: Boolean) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (highlighted) MaterialTheme.colorScheme.primary.copy(alpha = 0.08f)
                else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
            )
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            if (badge != null) {
                Spacer(Modifier.width(8.dp))
                Text(
                    badge,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White,
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary)
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
        }
        features.forEach { f ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = if (highlighted) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(8.dp))
                Text(f, color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun BuyButton(title: String, price: String, primary: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(if (primary) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            fontWeight = FontWeight.SemiBold,
            color = if (primary) Color.White else MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        if (price.isNotEmpty()) {
            Text(price, fontWeight = FontWeight.Bold, color = if (primary) Color.White else MaterialTheme.colorScheme.onSurface)
        }
    }
}

package life.lifememory.echosoftime.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Brown = Color(0xFFA2845E)
val BrownDeep = Color(0xFF8A6A45)
val BrownSoft = Color(0x1FA2845E)

private val LightColors = lightColorScheme(
    primary = Brown,
    onPrimary = Color.White,
    secondary = BrownDeep,
    background = Color(0xFFF2F2F7),
    surface = Color.White,
    onSurface = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFFF2F2F7),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB99A75),
    onPrimary = Color.Black,
    secondary = Color(0xFFC8A57C),
    background = Color.Black,
    surface = Color(0xFF1C1C1E),
    onSurface = Color.White,
)

@Composable
fun EchoesOfTimeTheme(
    dark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (dark) DarkColors else LightColors,
        content = content,
    )
}

module Main.Pages.Msg exposing (Msg(..))

import Pages.Home_
import Pages.Legacy


type Msg
    = Home_ Pages.Home_.Msg
    | Legacy Pages.Legacy.Msg

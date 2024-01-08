module Main.Pages.Msg exposing (Msg(..))

import Pages.Deployments_
import Pages.Home_
import Pages.Login_
import Pages.NotFound_


type Msg
    = Login_ Pages.Login_.Msg
    | Home_ Pages.Home_.Msg
    | Deployments_ Pages.Deployments_.Msg
    | NotFound_ Pages.NotFound_.Msg

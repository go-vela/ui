module Main.Pages.Model exposing (Model(..))

import Pages.Deployments_
import Pages.Home_
import Pages.Login_
import Pages.NotFound_
import View exposing (View)


type Model
    = Login_ Pages.Login_.Model
    | Home_ Pages.Home_.Model
    | Deployments_ Pages.Deployments_.Model
    | Redirecting_
    | Loading_
    | NotFound_ Pages.NotFound_.Model

module Main.Pages.Model exposing (Model(..))

import Pages.Home_
import Pages.Legacy
import View exposing (View)


type Model
    = Home_ Pages.Home_.Model
    | Legacy Pages.Legacy.Model

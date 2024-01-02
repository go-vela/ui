{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Pipeline.Model exposing (Download, Expand, Get, Msgs, PartialModel)

import Browser.Navigation as Navigation
import Pages exposing (Page)
import Shared
import Vela
    exposing
        ( BuildNumber
        , FocusFragment
        , Org
        , PipelineModel
        , PipelineTemplates
        , Ref
        , Repo
        )



-- MODEL


{-| PartialModel : an abbreviated version of the main model
-}
type alias PartialModel a =
    { a
        | shared : Shared.Model
        , navigationKey : Navigation.Key
        , page : Page
    }


type alias Msgs msg =
    { get : Get msg
    , expand : Expand msg
    , focusLineNumber : Int -> msg
    , showHideTemplates : msg
    , download : Download msg
    }


type alias Get msg =
    Org -> Repo -> BuildNumber -> Ref -> FocusFragment -> Bool -> msg


type alias Expand msg =
    Org -> Repo -> BuildNumber -> Ref -> FocusFragment -> Bool -> msg


type alias Download msg =
    String -> String -> msg

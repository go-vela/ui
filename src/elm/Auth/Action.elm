{--
SPDX-License-Identifier: Apache-2.0
--}


module Auth.Action exposing
    ( Action(..)
    , loadPageWithUser, showLoadingPage
    , replaceRoute, pushRoute, loadExternalUrl
    , view, subscriptions, command
    )

{-|

@docs Action
@docs loadPageWithUser, showLoadingPage
@docs replaceRoute, pushRoute, loadExternalUrl

@docs view, subscriptions, command

-}

import Dict exposing (Dict)
import Route.Path
import View exposing (View)


{-| Action : a type that represents the possible actions that can be taken in the application.
-}
type Action user
    = LoadPageWithUser user
    | ShowLoadingPage (View Never)
    | ReplaceRoute
        { path : Route.Path.Path
        , query : Dict String String
        , hash : Maybe String
        }
    | PushRoute
        { path : Route.Path.Path
        , query : Dict String String
        , hash : Maybe String
        }
    | LoadExternalUrl String


{-| loadPageWithUser : takes a user and returns an Action user.
-}
loadPageWithUser : user -> Action user
loadPageWithUser =
    LoadPageWithUser


{-| showLoadingPage : takes a view that never produces messages and returns an Action user.
-}
showLoadingPage : View Never -> Action user
showLoadingPage =
    ShowLoadingPage


{-| replaceRoute : takes a record with route info and returns an Action user.
-}
replaceRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Action user
replaceRoute =
    ReplaceRoute


{-| pushRoute : takes a record with route info and returns an Action user.
-}
pushRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Action user
pushRoute =
    PushRoute


{-| loadExternalUrl : takes a URL
-}
loadExternalUrl : String -> Action user
loadExternalUrl =
    LoadExternalUrl



-- USED INTERNALLY BY ELM LAND


{-| view : .
Used by Elm-Land; do not modify.
-}
view : (user -> View msg) -> Action user -> View msg
view toView authAction =
    case authAction of
        LoadPageWithUser user ->
            toView user

        ShowLoadingPage loadingView ->
            View.map never loadingView

        ReplaceRoute _ ->
            View.none

        PushRoute _ ->
            View.none

        LoadExternalUrl _ ->
            View.none


{-| subscriptions : takes in a function, that converts a user to a subscription msg, an Action user, and returns a subscription msg.
Used by Elm-Land; do not modify.
-}
subscriptions : (user -> Sub msg) -> Action user -> Sub msg
subscriptions toSub authAction =
    case authAction of
        LoadPageWithUser user ->
            toSub user

        ShowLoadingPage _ ->
            Sub.none

        ReplaceRoute _ ->
            Sub.none

        PushRoute _ ->
            Sub.none

        LoadExternalUrl _ ->
            Sub.none


{-| command : takes in a function, that converts a user to a command msg, an Action user, and returns a command msg.
Used by Elm-Land; do not modify.
-}
command : (user -> Cmd msg) -> Action user -> Cmd msg
command toCmd authAction =
    case authAction of
        LoadPageWithUser user ->
            toCmd user

        ShowLoadingPage _ ->
            Cmd.none

        ReplaceRoute _ ->
            Cmd.none

        PushRoute _ ->
            Cmd.none

        LoadExternalUrl _ ->
            Cmd.none

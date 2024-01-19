{--
SPDX-License-Identifier: Apache-2.0
--}


module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendMsg
    , pushRoute, replaceRoute, loadExternalUrl
    , map, toCmd
    , addAlertError, addAlertSuccess, alertsUpdate, clearRedirect, enableRepo, finishAuthentication, focusOn, getCurrentUser, getOrgRepos, getRepoBuilds, getRepoDeployments, gotoPage, handleHttpError, logout, pushPath, setRedirect, setTheme, updateFavorites
    )

{-|

@docs Effect
@docs none, batch
@docs sendCmd, sendMsg
@docs pushRoute, replaceRoute, loadExternalUrl

@docs map, toCmd

-}

import Api.Api as Api
import Api.Operations
import Auth.Session exposing (Session(..))
import Browser.Navigation
import Components.Alerts exposing (Alert)
import Components.Favorites as Favorites
import Dict exposing (Dict)
import Http
import Http.Detailed
import Interop
import Json.Encode
import Route
import Route.Path
import Shared.Model
import Shared.Msg
import Task
import Toasty as Alerting
import Url exposing (Url)
import Vela


type Effect msg
    = -- BASICS
      None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
      -- ROUTING
    | PushUrl String
    | ReplaceUrl String
    | LoadExternalUrl String
      -- SHARED
    | SendSharedMsg Shared.Msg.Msg



-- BASICS


{-| Don't send any effect.
-}
none : Effect msg
none =
    None


{-| Send multiple effects at once.
-}
batch : List (Effect msg) -> Effect msg
batch =
    Batch


{-| Send a normal `Cmd msg` as an effect, something like `Http.get` or `Random.generate`.
-}
sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


{-| Send a message as an effect. Useful when emitting events from UI components.
-}
sendMsg : msg -> Effect msg
sendMsg msg =
    Task.succeed msg
        |> Task.perform identity
        |> SendCmd



-- ROUTING


{-| Set the new route, and make the back button go back to the current route.
-}
pushRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
pushRoute route =
    PushUrl (Route.toString route)


{-| Set given path as route (without any query params or hash), and make the back button go back to the current route.
-}
pushPath :
    Route.Path.Path
    -> Effect msg
pushPath path =
    PushUrl (Route.toString { path = path, query = Dict.empty, hash = Nothing })


{-| Set the new route, but replace the previous one, so clicking the back
button **won't** go back to the previous route.
-}
replaceRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
replaceRoute route =
    ReplaceUrl (Route.toString route)


{-| Set given path as route (without any query params or hash), but replace the previous route,
so clicking the back button **won't** go back to the previous route
-}
replacePath :
    Route.Path.Path
    -> Effect msg
replacePath path =
    ReplaceUrl (Route.toString { path = path, query = Dict.empty, hash = Nothing })


{-| Redirect users to a new URL, somewhere external your web application.
-}
loadExternalUrl : String -> Effect msg
loadExternalUrl =
    LoadExternalUrl



-- INTERNALS


{-| Elm Land depends on this function to connect pages and layouts
together into the overall app.
-}
map : (msg1 -> msg2) -> Effect msg1 -> Effect msg2
map fn effect =
    case effect of
        None ->
            None

        Batch list ->
            Batch (List.map (map fn) list)

        SendCmd cmd ->
            SendCmd (Cmd.map fn cmd)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        LoadExternalUrl url ->
            LoadExternalUrl url

        SendSharedMsg sharedMsg ->
            SendSharedMsg sharedMsg


{-| Elm Land depends on this function to perform your effects.
-}
toCmd :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model.Model
    , fromSharedMsg : Shared.Msg.Msg -> msg
    , batch : List msg -> msg
    , toCmd : msg -> Cmd msg
    }
    -> Effect msg
    -> Cmd msg
toCmd options effect =
    case effect of
        None ->
            Cmd.none

        Batch list ->
            Cmd.batch (List.map (toCmd options) list)

        SendCmd cmd ->
            cmd

        PushUrl url ->
            Browser.Navigation.pushUrl options.key url

        ReplaceUrl url ->
            Browser.Navigation.replaceUrl options.key url

        LoadExternalUrl url ->
            Browser.Navigation.load url

        SendSharedMsg sharedMsg ->
            Task.succeed sharedMsg
                |> Task.perform options.fromSharedMsg



-- CUSTOM EFFECTS


setTheme : { theme : Vela.Theme } -> Effect msg
setTheme options =
    SendSharedMsg <| Shared.Msg.SetTheme options


setRedirect : { redirect : String } -> Effect msg
setRedirect options =
    sendCmd <| Interop.setRedirect <| Json.Encode.string options.redirect


clearRedirect : {} -> Effect msg
clearRedirect _ =
    sendCmd <| Interop.setRedirect <| Json.Encode.null


finishAuthentication : { code : Maybe String, state : Maybe String } -> Effect msg
finishAuthentication options =
    SendSharedMsg <| Shared.Msg.FinishAuthentication options


logout : {} -> Effect msg
logout _ =
    SendSharedMsg <| Shared.Msg.Logout


getCurrentUser : {} -> Effect msg
getCurrentUser _ =
    SendSharedMsg <| Shared.Msg.GetCurrentUser


updateFavorites : { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType } -> Effect msg
updateFavorites options =
    SendSharedMsg <| Shared.Msg.UpdateFavorites options


enableRepo :
    { baseUrl : String
    , session : Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ) -> msg
    , repo : Vela.Repository
    }
    -> Effect msg
enableRepo options =
    let
        payload : Vela.EnableRepositoryPayload
        payload =
            Vela.buildEnableRepositoryPayload options.repo

        body : Http.Body
        body =
            Http.jsonBody <| Vela.encodeEnableRepository payload
    in
    Api.try
        options.onResponse
        (Api.Operations.enableRepo options.baseUrl options.session body)
        |> sendCmd


getRepoBuilds :
    { baseUrl : String
    , session : Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , maybeEvent : Maybe String
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoBuilds options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoBuilds options.baseUrl options.session options)
        |> sendCmd


getOrgRepos :
    { baseUrl : String
    , session : Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ) -> msg
    , org : String
    }
    -> Effect msg
getOrgRepos options =
    Api.try
        options.onResponse
        (Api.Operations.getOrgRepos options.baseUrl options.session options)
        |> sendCmd


getRepoDeployments :
    { baseUrl : String
    , session : Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Deployment ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoDeployments options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoDeployments options.baseUrl options.session options)
        |> sendCmd


gotoPage : { pageNumber : Int } -> Effect msg
gotoPage options =
    SendSharedMsg <| Shared.Msg.GotoPage options


handleHttpError : { httpError : Http.Detailed.Error String } -> Effect msg
handleHttpError options =
    SendSharedMsg <| Shared.Msg.HandleHttpError options.httpError


addAlertSuccess : { content : String, addToastIfUnique : Bool } -> Effect msg
addAlertSuccess options =
    SendSharedMsg <| Shared.Msg.AddAlertSuccess options


addAlertError : { content : String, addToastIfUnique : Bool } -> Effect msg
addAlertError options =
    SendSharedMsg <| Shared.Msg.AddAlertError options


alertsUpdate : { alert : Alerting.Msg Alert } -> Effect msg
alertsUpdate options =
    SendSharedMsg <| Shared.Msg.AlertsUpdate options.alert


focusOn : { target : String } -> Effect msg
focusOn options =
    SendSharedMsg <| Shared.Msg.FocusOn options

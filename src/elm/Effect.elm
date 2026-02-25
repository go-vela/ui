{--
SPDX-License-Identifier: Apache-2.0
--}


module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendMsg
    , pushRoute, replaceRoute, loadExternalUrl
    , map, toCmd
    , addAlertError, addAlertSuccess, addDeployment, addFavorites, addOrgSecret, addRepoSchedule, addRepoSecret, addSharedSecret, alertsUpdate, approveBuild, cancelBuild, chownRepo, clearRedirect, deleteOrgSecret, deleteRepoSchedule, deleteRepoSecret, deleteSharedSecret, disableRepo, downloadFile, enableRepo, expandPipelineConfig, finishAuthentication, focusOn, getAllBuildServices, getAllBuildSteps, getAllBuilds, getBuild, getBuildArtifacts, getBuildGraph, getBuildServiceLog, getBuildServices, getBuildStepLog, getBuildSteps, getCurrentUser, getCurrentUserShared, getDashboard, getDashboards, getDeploymentConfig, getOrgBuilds, getOrgRepos, getOrgSecret, getOrgSecrets, getPipelineConfig, getPipelineTemplates, getRepo, getRepoBuilds, getRepoBuildsShared, getRepoDeployments, getRepoHooks, getRepoHooksShared, getRepoSchedule, getRepoSchedules, getRepoSecret, getRepoSecrets, getSettings, getSharedSecret, getSharedSecrets, getWorkers, handleHttpError, logout, pushPath, redeliverHook, repairRepo, replacePath, replaceRouteRemoveTabHistorySkipDomFocus, restartBuild, setRedirect, setTheme, updateFavicon, updateFavorite, updateOrgSecret, updateRepo, updateRepoHooksShared, updateRepoSchedule, updateRepoSecret, updateSettings, updateSharedSecret, updateSourceReposShared
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
import Auth.Session
import Browser.Navigation
import Components.Alerts
import Dict exposing (Dict)
import Http
import Http.Detailed
import Interop
import Json.Encode
import RemoteData exposing (WebData)
import Route
import Route.Path
import Shared.Model
import Shared.Msg
import Task
import Toasty as Alerting
import Url exposing (Url)
import Utils.Favicons as Favicons
import Utils.Favorites as Favorites
import Utils.Theme as Theme
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


setTheme : { theme : Theme.Theme } -> Effect msg
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


logout : { from : Maybe String } -> Effect msg
logout options =
    SendSharedMsg <| Shared.Msg.Logout options


getCurrentUser :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.User ) -> msg
    }
    -> Effect msg
getCurrentUser options =
    Api.try
        options.onResponse
        (Api.Operations.getCurrentUser
            options.baseUrl
            options.session
        )
        |> sendCmd


getCurrentUserShared : {} -> Effect msg
getCurrentUserShared _ =
    SendSharedMsg <| Shared.Msg.GetCurrentUser


addFavorites : { favorites : List { org : String, maybeRepo : Maybe String } } -> Effect msg
addFavorites options =
    SendSharedMsg <| Shared.Msg.AddFavorites options


updateFavorite : { org : String, maybeRepo : Maybe String, updateType : Favorites.UpdateType } -> Effect msg
updateFavorite options =
    SendSharedMsg <| Shared.Msg.UpdateFavorite options


getRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ) -> msg
    , org : String
    , repo : String
    }
    -> Effect msg
getRepo options =
    Api.try
        options.onResponse
        (Api.Operations.getRepo
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


enableRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ) -> msg
    , body : Http.Body
    }
    -> Effect msg
enableRepo options =
    Api.try
        options.onResponse
        (Api.Operations.enableRepo
            options.baseUrl
            options.session
            options.body
        )
        |> sendCmd


updateRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ) -> msg
    , org : String
    , repo : String
    , body : Http.Body
    }
    -> Effect msg
updateRepo options =
    Api.try
        options.onResponse
        (Api.Operations.updateRepo
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


disableRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    }
    -> Effect msg
disableRepo options =
    Api.tryString
        options.onResponse
        (Api.Operations.disableRepo
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


repairRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    }
    -> Effect msg
repairRepo options =
    Api.tryString
        options.onResponse
        (Api.Operations.repairRepo
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


chownRepo :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    }
    -> Effect msg
chownRepo options =
    Api.tryString
        options.onResponse
        (Api.Operations.chownRepo
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getOrgRepos :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    }
    -> Effect msg
getOrgRepos options =
    Api.try
        options.onResponse
        (Api.Operations.getOrgRepos
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getOrgBuilds :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , maybeEvent : Maybe String
    , org : String
    }
    -> Effect msg
getOrgBuilds options =
    Api.try
        options.onResponse
        (Api.Operations.getOrgBuilds
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoBuildsShared :
    { pageNumber : Maybe Int
    , perPage : Maybe Int
    , maybeEvent : Maybe String
    , maybeAfter : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoBuildsShared options =
    SendSharedMsg <| Shared.Msg.GetRepoBuilds options


updateSourceReposShared : { sourceRepos : WebData Vela.SourceRepositories } -> Effect msg
updateSourceReposShared options =
    SendSharedMsg <| Shared.Msg.UpdateSourceRepos options


getRepoDeployments :
    { baseUrl : String
    , session : Auth.Session.Session
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
        (Api.Operations.getRepoDeployments
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getWorkers :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Worker ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    }
    -> Effect msg
getWorkers options =
    Api.try
        options.onResponse
        (Api.Operations.getWorkers
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getSettings :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ) -> msg
    }
    -> Effect msg
getSettings options =
    Api.try
        options.onResponse
        (Api.Operations.getSettings
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateSettings :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ) -> msg
    , body : Http.Body
    }
    -> Effect msg
updateSettings options =
    Api.try
        options.onResponse
        (Api.Operations.updateSettings
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


restartBuild :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
restartBuild options =
    Api.try
        options.onResponse
        (Api.Operations.restartBuild options.baseUrl options.session options)
        |> sendCmd


cancelBuild :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
cancelBuild options =
    Api.try
        options.onResponse
        (Api.Operations.cancelBuild options.baseUrl options.session options)
        |> sendCmd


approveBuild :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
approveBuild options =
    Api.try
        options.onResponse
        (Api.Operations.approveBuild options.baseUrl options.session options)
        |> sendCmd


addDeployment :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Deployment ) -> msg
    , org : String
    , repo : String
    , body : Http.Body
    }
    -> Effect msg
addDeployment options =
    Api.try
        options.onResponse
        (Api.Operations.addDeployment
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getDeploymentConfig :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.DeploymentConfig ) -> msg
    , ref : Maybe String
    , org : String
    , repo : String
    }
    -> Effect msg
getDeploymentConfig options =
    Api.try
        options.onResponse
        (Api.Operations.getDeploymentConfig
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoHooks :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Hook ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoHooks options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoHooks
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoHooksShared :
    { pageNumber : Maybe Int
    , perPage : Maybe Int
    , maybeEvent : Maybe String
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoHooksShared options =
    SendSharedMsg <| Shared.Msg.GetRepoHooks options


updateRepoHooksShared : { hooks : WebData (List Vela.Hook) } -> Effect msg
updateRepoHooksShared options =
    SendSharedMsg <| Shared.Msg.UpdateRepoHooks options


redeliverHook :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    , hookNumber : String
    }
    -> Effect msg
redeliverHook options =
    Api.try
        options.onResponse
        (Api.Operations.redeliverHook
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoSchedules :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Schedule ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoSchedules options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoSchedules
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoSchedule :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ) -> msg
    , org : String
    , repo : String
    , name : String
    }
    -> Effect msg
getRepoSchedule options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoSchedule
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


addRepoSchedule :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ) -> msg
    , org : String
    , repo : String
    , name : String
    , body : Http.Body
    }
    -> Effect msg
addRepoSchedule options =
    Api.try
        options.onResponse
        (Api.Operations.addRepoSchedule
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateRepoSchedule :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Schedule ) -> msg
    , org : String
    , repo : String
    , name : String
    , body : Http.Body
    }
    -> Effect msg
updateRepoSchedule options =
    Api.try
        options.onResponse
        (Api.Operations.updateRepoSchedule
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


deleteRepoSchedule :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    , name : String
    }
    -> Effect msg
deleteRepoSchedule options =
    Api.tryString
        options.onResponse
        (Api.Operations.deleteRepoSchedule
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuild :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getBuild options =
    Api.try
        options.onResponse
        (Api.Operations.getBuild
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuildSteps :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getBuildSteps options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildSteps
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getAllBuilds :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ) -> msg
    , org : String
    , repo : String
    , after : Int
    }
    -> Effect msg
getAllBuilds options =
    Api.tryAll
        options.onResponse
        (Api.Operations.getAllBuilds
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getAllBuildSteps :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Step ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getAllBuildSteps options =
    Api.tryAll
        options.onResponse
        (Api.Operations.getAllBuildSteps
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuildServices :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Service ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getBuildServices options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildServices
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getAllBuildServices :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Service ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getAllBuildServices options =
    Api.tryAll
        options.onResponse
        (Api.Operations.getAllBuildServices
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuildStepLog :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ) -> msg
    , org : String
    , repo : String
    , build : String
    , stepNumber : String
    }
    -> Effect msg
getBuildStepLog options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildStepLog
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuildServiceLog :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Log ) -> msg
    , org : String
    , repo : String
    , build : String
    , serviceNumber : String
    }
    -> Effect msg
getBuildServiceLog options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildServiceLog
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getPipelineConfig :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PipelineConfig ) -> msg
    , org : String
    , repo : String
    , ref : String
    }
    -> Effect msg
getPipelineConfig options =
    Api.try
        options.onResponse
        (Api.Operations.getPipelineConfig
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


expandPipelineConfig :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , org : String
    , repo : String
    , ref : String
    }
    -> Effect msg
expandPipelineConfig options =
    Api.tryString
        options.onResponse
        (Api.Operations.expandPipelineConfig
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getPipelineTemplates :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Dict String Vela.Template ) -> msg
    , org : String
    , repo : String
    , ref : String
    }
    -> Effect msg
getPipelineTemplates options =
    Api.try
        options.onResponse
        (Api.Operations.getPipelineTemplates
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getBuildGraph :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.BuildGraph ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getBuildGraph options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildGraph
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getOrgSecrets :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , engine : String
    , org : String
    }
    -> Effect msg
getOrgSecrets options =
    Api.try
        options.onResponse
        (Api.Operations.getOrgSecrets
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getOrgSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , name : String
    }
    -> Effect msg
getOrgSecret options =
    Api.try
        options.onResponse
        (Api.Operations.getOrgSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateOrgSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , name : String
    , body : Http.Body
    }
    -> Effect msg
updateOrgSecret options =
    Api.try
        options.onResponse
        (Api.Operations.updateOrgSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


addOrgSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , body : Http.Body
    }
    -> Effect msg
addOrgSecret options =
    Api.try
        options.onResponse
        (Api.Operations.addOrgSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


deleteOrgSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , engine : String
    , org : String
    , name : String
    }
    -> Effect msg
deleteOrgSecret options =
    Api.tryString
        options.onResponse
        (Api.Operations.deleteOrgSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoSecrets :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ) -> msg
    , engine : String
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoSecrets options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoSecrets
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , repo : String
    , name : String
    }
    -> Effect msg
getRepoSecret options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateRepoSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , repo : String
    , name : String
    , body : Http.Body
    }
    -> Effect msg
updateRepoSecret options =
    Api.try
        options.onResponse
        (Api.Operations.updateRepoSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


addRepoSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , repo : String
    , body : Http.Body
    }
    -> Effect msg
addRepoSecret options =
    Api.try
        options.onResponse
        (Api.Operations.addRepoSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


deleteRepoSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , engine : String
    , org : String
    , repo : String
    , name : String
    }
    -> Effect msg
deleteRepoSecret options =
    Api.tryString
        options.onResponse
        (Api.Operations.deleteRepoSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getSharedSecrets :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Secret ) -> msg
    , engine : String
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , org : String
    , team : String
    }
    -> Effect msg
getSharedSecrets options =
    Api.try
        options.onResponse
        (Api.Operations.getSharedSecrets
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getSharedSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , team : String
    , name : String
    }
    -> Effect msg
getSharedSecret options =
    Api.try
        options.onResponse
        (Api.Operations.getSharedSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateSharedSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , team : String
    , name : String
    , body : Http.Body
    }
    -> Effect msg
updateSharedSecret options =
    Api.try
        options.onResponse
        (Api.Operations.updateSharedSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


addSharedSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ) -> msg
    , engine : String
    , org : String
    , team : String
    , body : Http.Body
    }
    -> Effect msg
addSharedSecret options =
    Api.try
        options.onResponse
        (Api.Operations.addSharedSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


deleteSharedSecret :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, String ) -> msg
    , engine : String
    , org : String
    , team : String
    , name : String
    }
    -> Effect msg
deleteSharedSecret options =
    Api.tryString
        options.onResponse
        (Api.Operations.deleteSharedSecret
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getRepoBuilds :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ) -> msg
    , pageNumber : Maybe Int
    , perPage : Maybe Int
    , maybeEvent : Maybe String
    , maybeAfter : Maybe Int
    , org : String
    , repo : String
    }
    -> Effect msg
getRepoBuilds options =
    Api.try
        options.onResponse
        (Api.Operations.getRepoBuilds
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


updateFavicon : { favicon : Favicons.Favicon } -> Effect msg
updateFavicon options =
    SendSharedMsg <| Shared.Msg.UpdateFavicon options


handleHttpError : { error : Http.Detailed.Error String, shouldShowAlertFn : Http.Detailed.Error String -> Bool } -> Effect msg
handleHttpError options =
    SendSharedMsg <| Shared.Msg.HandleHttpError options


addAlertSuccess : { content : String, addToastIfUnique : Bool, link : Maybe Components.Alerts.Link } -> Effect msg
addAlertSuccess options =
    SendSharedMsg <| Shared.Msg.AddAlertSuccess options


addAlertError : { content : String, addToastIfUnique : Bool, link : Maybe Components.Alerts.Link } -> Effect msg
addAlertError options =
    SendSharedMsg <| Shared.Msg.AddAlertError options


alertsUpdate : { alert : Alerting.Msg Components.Alerts.Alert } -> Effect msg
alertsUpdate options =
    SendSharedMsg <| Shared.Msg.AlertsUpdate options.alert


focusOn : { target : String } -> Effect msg
focusOn options =
    SendSharedMsg <| Shared.Msg.FocusOn options


downloadFile : { filename : String, content : String, map : String -> String } -> Effect msg
downloadFile options =
    SendSharedMsg <| Shared.Msg.DownloadFile options


replaceRouteRemoveTabHistorySkipDomFocus : Route.Route params -> Effect msg
replaceRouteRemoveTabHistorySkipDomFocus route =
    if Dict.get "tab_switch" route.query /= Nothing then
        replaceRoute
            { path = route.path
            , query =
                route.query
                    |> Dict.remove "tab_switch"
            , hash = route.hash
            }

    else
        none


getDashboard :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Dashboard ) -> msg
    , dashboardId : String
    }
    -> Effect msg
getDashboard options =
    Api.try
        options.onResponse
        (Api.Operations.getDashboard
            options.baseUrl
            options.session
            options
        )
        |> sendCmd


getDashboards :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Dashboard ) -> msg
    }
    -> Effect msg
getDashboards options =
    Api.try
        options.onResponse
        (Api.Operations.getDashboards
            options.baseUrl
            options.session
        )
        |> sendCmd


getBuildArtifacts :
    { baseUrl : String
    , session : Auth.Session.Session
    , onResponse : Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.ArtifactObject ) -> msg
    , org : String
    , repo : String
    , build : String
    }
    -> Effect msg
getBuildArtifacts options =
    Api.try
        options.onResponse
        (Api.Operations.getBuildArtifacts
            options.baseUrl
            options.session
            options
        )
        |> sendCmd

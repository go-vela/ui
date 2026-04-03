{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Settings exposing (Model, Msg, page)

import Auth
import Components.Form
import Components.Loading
import Dict
import Effect exposing (Effect)
import Html exposing (Html, div, h2, i, li, p, section, span, strong, text, ul)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Json.Decode exposing (Error(..))
import Layouts
import List.Extra
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import String
import Time
import Utils.Errors as Errors
import Utils.Helpers as Util
import Utils.Interval as Interval
import Vela exposing (defaultCompilerPayload, defaultQueuePayload, defaultScmPayload, defaultSettingsPayload)
import View exposing (View)


{-| ImageRestrictionListForm : form state for managing the two-field image restriction lists.
-}
type alias ImageRestrictionListForm =
    { imageVal : String
    , reasonVal : String
    , editing : Dict String String
    }


{-| page : shared model, route, and returns the page.
-}
page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


{-| toLayout : takes model and passes the page info to Layouts.
-}
toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default_Admin
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "View Settings"
              , content = "vela view settings"
              , docs = Just "cli/settings/view"
              }
            , { name = "Update Settings"
              , content = "vela update settings"
              , docs = Just "cli/settings/update"
              }
            ]
        , crumbs =
            [ ( "Admin", Nothing )
            ]
        }



-- INIT


{-| Model : alias for model for the page.
-}
type alias Model =
    { settings : WebData Vela.PlatformSettings
    , originalSettings : Maybe Vela.PlatformSettings
    , exported : WebData String
    , cloneImage : String
    , starlarkExecLimitIn : String
    , templateDepthIn : String
    , queueRoutes : Components.Form.EditableListForm
    , repoAllowlist : Components.Form.EditableListForm
    , scheduleAllowlist : Components.Form.EditableListForm
    , scmOrgRoleMap : Components.Form.EditableListForm
    , scmRepoRoleMap : Components.Form.EditableListForm
    , scmTeamRoleMap : Components.Form.EditableListForm
    , maxDashboardReposIn : String
    , queueRestartLimitIn : String
    , enableOrgSecrets : Bool
    , enableRepoSecrets : Bool
    , enableSharedSecrets : Bool
    , blockedImages : ImageRestrictionListForm
    , warnImages : ImageRestrictionListForm
    }


{-| init : initializes page with no arguments.
-}
init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { settings = RemoteData.Loading
      , originalSettings = Nothing
      , exported = RemoteData.Loading
      , cloneImage = ""
      , starlarkExecLimitIn = ""
      , templateDepthIn = ""
      , queueRoutes = { val = "", editing = Dict.empty }
      , repoAllowlist = { val = "", editing = Dict.empty }
      , scheduleAllowlist = { val = "", editing = Dict.empty }
      , scmOrgRoleMap = { val = "", editing = Dict.empty }
      , scmRepoRoleMap = { val = "", editing = Dict.empty }
      , scmTeamRoleMap = { val = "", editing = Dict.empty }
      , maxDashboardReposIn = ""
      , queueRestartLimitIn = ""
      , enableOrgSecrets = False
      , enableRepoSecrets = False
      , enableSharedSecrets = False
      , blockedImages = { imageVal = "", reasonVal = "", editing = Dict.empty }
      , warnImages = { imageVal = "", reasonVal = "", editing = Dict.empty }
      }
    , Effect.getSettings
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetSettingsResponse
        }
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = -- SETTINGS
      GetSettingsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ))
    | RefreshSettingsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ))
    | UpdateSettingsResponse { field : Vela.PlatformSettingsFieldUpdate } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ))
      -- COMPILER
    | CloneImageOnInput String
    | CloneImageOnUpdate String
    | StarlarkExecLimitOnInput String
    | StarlarkExecLimitOnUpdate String
    | TemplateDepthOnInput String
    | TemplateDepthOnUpdate String
      -- QUEUE
    | QueueRoutesOnInput String
    | QueueRoutesAddOnClick String
    | QueueRoutesEditOnClick { id : String }
    | QueueRoutesSaveOnClick { id : String, val : String }
    | QueueRoutesEditOnInput { id : String } String
    | QueueRoutesRemoveOnClick String
      -- REPOS
    | RepoAllowlistOnInput String
    | RepoAllowlistAddOnClick String
    | RepoAllowlistEditOnClick { id : String }
    | RepoAllowlistSaveOnClick { id : String, val : String }
    | RepoAllowlistEditOnInput { id : String } String
    | RepoAllowlistRemoveOnClick String
      -- SCHEDULES
    | ScheduleAllowlistOnInput String
    | ScheduleAllowlistAddOnClick String
    | ScheduleAllowlistEditOnClick { id : String }
    | ScheduleAllowlistSaveOnClick { id : String, val : String }
    | ScheduleAllowlistEditOnInput { id : String } String
    | ScheduleAllowlistRemoveOnClick String
      -- SCM ROLE MAPS
    | ScmOrgRoleMapOnInput String
    | ScmOrgRoleMapAddOnClick String
    | ScmOrgRoleMapEditOnClick { id : String }
    | ScmOrgRoleMapSaveOnClick { id : String, val : String }
    | ScmOrgRoleMapEditOnInput { id : String } String
    | ScmOrgRoleMapRemoveOnClick String
    | ScmRepoRoleMapOnInput String
    | ScmRepoRoleMapAddOnClick String
    | ScmRepoRoleMapEditOnClick { id : String }
    | ScmRepoRoleMapSaveOnClick { id : String, val : String }
    | ScmRepoRoleMapEditOnInput { id : String } String
    | ScmRepoRoleMapRemoveOnClick String
    | ScmTeamRoleMapOnInput String
    | ScmTeamRoleMapAddOnClick String
    | ScmTeamRoleMapEditOnClick { id : String }
    | ScmTeamRoleMapSaveOnClick { id : String, val : String }
    | ScmTeamRoleMapEditOnInput { id : String } String
    | ScmTeamRoleMapRemoveOnClick String
      -- DASHBOARDS
    | MaxDashboardReposOnInput String
    | MaxDashboardReposOnUpdate String
      -- QUEUE LIMIT
    | QueueRestartLimitOnInput String
    | QueueRestartLimitOnUpdate String
      -- SECRETS
    | ToggleOrgSecrets Bool
    | ToggleRepoSecrets Bool
    | ToggleSharedSecrets Bool
      -- BLOCKED IMAGES
    | BlockedImagesImageOnInput String
    | BlockedImagesReasonOnInput String
    | BlockedImagesAddOnClick String String
    | BlockedImagesEditOnClick { id : String }
    | BlockedImagesSaveOnClick { id : String, val : String }
    | BlockedImagesEditOnInput { id : String } String
    | BlockedImagesRemoveOnClick String
      -- WARN IMAGES
    | WarnImagesImageOnInput String
    | WarnImagesReasonOnInput String
    | WarnImagesAddOnClick String String
    | WarnImagesEditOnClick { id : String }
    | WarnImagesSaveOnClick { id : String, val : String }
    | WarnImagesEditOnInput { id : String } String
    | WarnImagesRemoveOnClick String
      -- REFRESH
    | Tick { time : Time.Posix, interval : Interval.Interval }


{-| update : takes current models, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetSettingsResponse response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | originalSettings = Just settings
                        , settings = RemoteData.Success settings
                        , cloneImage = settings.compiler.cloneImage
                        , starlarkExecLimitIn = String.fromInt settings.compiler.starlarkExecLimit
                        , templateDepthIn = String.fromInt settings.compiler.templateDepth
                        , maxDashboardReposIn = String.fromInt settings.maxDashboardRepos
                        , queueRestartLimitIn = String.fromInt settings.queueRestartLimit
                        , enableOrgSecrets = settings.enableOrgSecrets
                        , enableRepoSecrets = settings.enableRepoSecrets
                        , enableSharedSecrets = settings.enableSharedSecrets
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | settings = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        RefreshSettingsResponse response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | settings =
                            case model.settings of
                                RemoteData.Success s ->
                                    if settings.updatedAt < s.updatedAt then
                                        model.settings

                                    else
                                        RemoteData.Success settings

                                _ ->
                                    RemoteData.Success settings
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | settings = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        UpdateSettingsResponse options response ->
            case response of
                Ok ( meta, settings ) ->
                    let
                        responseConfig =
                            Vela.platformSettingsFieldUpdateToResponseConfig options.field
                    in
                    ( { model
                        | settings = RemoteData.Success settings
                      }
                    , Effect.addAlertSuccess
                        { content = responseConfig.successAlert settings
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- COMPILER
        CloneImageOnInput val ->
            ( { model
                | cloneImage = val
              }
            , Effect.none
            )

        CloneImageOnUpdate val ->
            let
                compilerPayload =
                    { defaultCompilerPayload
                        | cloneImage = Just val
                    }

                payload =
                    { defaultSettingsPayload
                        | compiler = Just compilerPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | cloneImage = val
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.CompilerCloneImage
                        }
                , body = body
                }
            )

        StarlarkExecLimitOnInput val ->
            ( { model
                | starlarkExecLimitIn = val
              }
            , Effect.none
            )

        StarlarkExecLimitOnUpdate val ->
            let
                compilerPayload =
                    { defaultCompilerPayload
                        | starlarkExecLimit = String.toInt val
                    }

                payload =
                    { defaultSettingsPayload
                        | compiler = Just compilerPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | starlarkExecLimitIn = val
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.CompilerStarlarkExecLimit
                        }
                , body = body
                }
            )

        TemplateDepthOnInput val ->
            ( { model
                | templateDepthIn = Components.Form.handleNumberInputString model.templateDepthIn val
              }
            , Effect.none
            )

        TemplateDepthOnUpdate val ->
            let
                compilerPayload =
                    { defaultCompilerPayload
                        | templateDepth = String.toInt val
                    }

                payload =
                    { defaultSettingsPayload
                        | compiler = Just compilerPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | templateDepthIn = val
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.CompilerTemplateDepth
                        }
                , body = body
                }
            )

        -- QUEUE
        QueueRoutesOnInput val ->
            let
                editableListForm =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes = { editableListForm | val = val }
              }
            , Effect.none
            )

        QueueRoutesAddOnClick val ->
            let
                currentRoutes =
                    RemoteData.unwrap [] (.queue >> .routes) model.settings

                effect =
                    if not <| List.member val currentRoutes then
                        let
                            queuePayload =
                                { defaultQueuePayload
                                    | routes = Just <| List.Extra.unique <| val :: currentRoutes
                                }

                            payload =
                                { defaultSettingsPayload
                                    | queue = Just queuePayload
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.QueueRouteAdd val
                                    }
                            , body = body
                            }

                    else
                        Effect.addAlertSuccess
                            { content = "Queue route '" ++ val ++ "' already exists."
                            , addToastIfUnique = False
                            , link = Nothing
                            }

                editableListForm =
                    model.queueRoutes
            in
            ( { model | queueRoutes = { editableListForm | val = "" } }
            , effect
            )

        QueueRoutesRemoveOnClick val ->
            let
                queuePayload =
                    { defaultQueuePayload
                        | routes = Just <| List.Extra.remove val <| RemoteData.unwrap [] (.queue >> .routes) model.settings
                    }

                payload =
                    { defaultSettingsPayload
                        | queue = Just queuePayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.queueRoutes
            in
            ( { model | queueRoutes = { editableListForm | editing = Dict.remove val editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.QueueRouteRemove val
                        }
                , body = body
                }
            )

        QueueRoutesEditOnClick options ->
            let
                queueRoutes =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes =
                    { queueRoutes
                        | editing = Dict.insert options.id options.id model.queueRoutes.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId queueRoutesHtmlId options.id }
            )

        QueueRoutesSaveOnClick options ->
            let
                effect =
                    if options.id /= options.val && String.length options.val > 0 then
                        let
                            queuePayload =
                                { defaultQueuePayload
                                    | routes =
                                        model.settings
                                            |> RemoteData.unwrap [] (.queue >> .routes)
                                            |> List.Extra.updateIf (\item -> item == options.id) (\_ -> options.val)
                                            |> Just
                                }

                            payload =
                                { defaultSettingsPayload
                                    | queue = Just queuePayload
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.QueueRouteUpdate options.id options.val
                                    }
                            , body = body
                            }

                    else
                        Effect.none

                editableListForm =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes =
                    { editableListForm
                        | editing = Dict.remove options.id model.queueRoutes.editing
                    }
              }
            , effect
            )

        QueueRoutesEditOnInput options val ->
            let
                editableListForm =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes =
                    { editableListForm
                        | editing = Dict.insert options.id val model.queueRoutes.editing
                    }
              }
            , Effect.none
            )

        -- REPOS
        RepoAllowlistOnInput val ->
            let
                editableListForm =
                    model.repoAllowlist
            in
            ( { model
                | repoAllowlist = { editableListForm | val = val }
              }
            , Effect.none
            )

        RepoAllowlistAddOnClick val ->
            let
                currentRepos =
                    RemoteData.unwrap [] .repoAllowlist model.settings

                effect =
                    if not <| List.member val currentRepos then
                        let
                            payload =
                                { defaultSettingsPayload
                                    | repoAllowlist = Just <| List.Extra.unique <| val :: currentRepos
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.RepoAllowlistAdd val
                                    }
                            , body = body
                            }

                    else
                        Effect.addAlertSuccess
                            { content = "Repo '" ++ val ++ "' already exists in overall allowlist."
                            , addToastIfUnique = False
                            , link = Nothing
                            }

                editableListForm =
                    model.repoAllowlist
            in
            ( { model | repoAllowlist = { editableListForm | val = "" } }
            , effect
            )

        RepoAllowlistRemoveOnClick val ->
            let
                payload =
                    { defaultSettingsPayload
                        | repoAllowlist = Just <| List.Extra.remove val <| RemoteData.unwrap [] .repoAllowlist model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.repoAllowlist
            in
            ( { model | repoAllowlist = { editableListForm | editing = Dict.remove val editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.RepoAllowlistRemove val
                        }
                , body = body
                }
            )

        RepoAllowlistEditOnClick options ->
            let
                editableListForm =
                    model.repoAllowlist
            in
            ( { model
                | repoAllowlist =
                    { editableListForm
                        | editing = Dict.insert options.id options.id model.repoAllowlist.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId repoAllowlistHtmlId options.id }
            )

        RepoAllowlistSaveOnClick options ->
            let
                effect =
                    if options.id /= options.val && String.length options.val > 0 then
                        let
                            payload =
                                { defaultSettingsPayload
                                    | repoAllowlist =
                                        model.settings
                                            |> RemoteData.unwrap [] .repoAllowlist
                                            |> List.Extra.updateIf (\item -> item == options.id) (\_ -> options.val)
                                            |> Just
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.RepoAllowlistUpdate options.id options.val
                                    }
                            , body = body
                            }

                    else
                        Effect.none

                editableListForm =
                    model.repoAllowlist
            in
            ( { model
                | repoAllowlist =
                    { editableListForm
                        | editing = Dict.remove options.id model.repoAllowlist.editing
                    }
              }
            , effect
            )

        RepoAllowlistEditOnInput options val ->
            let
                editableListForm =
                    model.repoAllowlist
            in
            ( { model
                | repoAllowlist =
                    { editableListForm
                        | editing = Dict.insert options.id val model.repoAllowlist.editing
                    }
              }
            , Effect.none
            )

        -- SCHEDULES
        ScheduleAllowlistOnInput val ->
            let
                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model
                | scheduleAllowlist = { editableListForm | val = val }
              }
            , Effect.none
            )

        ScheduleAllowlistAddOnClick val ->
            let
                currentRepos =
                    RemoteData.unwrap [] .scheduleAllowlist model.settings

                effect =
                    if not <| List.member val currentRepos then
                        let
                            payload =
                                { defaultSettingsPayload
                                    | scheduleAllowlist = Just <| List.Extra.unique <| val :: RemoteData.unwrap [] .scheduleAllowlist model.settings
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.ScheduleAllowlistAdd val
                                    }
                            , body = body
                            }

                    else
                        Effect.addAlertSuccess
                            { content = "Repo '" ++ val ++ "' already exists in schedule allowlist."
                            , addToastIfUnique = False
                            , link = Nothing
                            }

                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model | scheduleAllowlist = { editableListForm | val = "" } }
            , effect
            )

        ScheduleAllowlistRemoveOnClick val ->
            let
                payload =
                    { defaultSettingsPayload
                        | scheduleAllowlist = Just <| List.Extra.remove val <| RemoteData.unwrap [] .scheduleAllowlist model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model | scheduleAllowlist = { editableListForm | editing = Dict.remove val editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.ScheduleAllowlistRemove val
                        }
                , body = body
                }
            )

        ScheduleAllowlistEditOnClick options ->
            let
                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model
                | scheduleAllowlist =
                    { editableListForm
                        | editing = Dict.insert options.id options.id model.scheduleAllowlist.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId scheduleAllowlistHtmlId options.id }
            )

        ScheduleAllowlistSaveOnClick options ->
            let
                effect =
                    if options.id /= options.val && String.length options.val > 0 then
                        let
                            payload =
                                { defaultSettingsPayload
                                    | scheduleAllowlist =
                                        model.settings
                                            |> RemoteData.unwrap [] .scheduleAllowlist
                                            |> List.Extra.updateIf (\item -> item == options.id) (\_ -> options.val)
                                            |> Just
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.ScheduleAllowlistUpdate options.id options.val
                                    }
                            , body = body
                            }

                    else
                        Effect.none

                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model
                | scheduleAllowlist =
                    { editableListForm
                        | editing = Dict.remove options.id model.scheduleAllowlist.editing
                    }
              }
            , effect
            )

        ScheduleAllowlistEditOnInput options val ->
            let
                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model
                | scheduleAllowlist =
                    { editableListForm
                        | editing = Dict.insert options.id val model.scheduleAllowlist.editing
                    }
              }
            , Effect.none
            )

        -- SCM ROLE MAPS
        ScmOrgRoleMapOnInput val ->
            let
                editableListForm =
                    model.scmOrgRoleMap
            in
            ( { model
                | scmOrgRoleMap = { editableListForm | val = val }
              }
            , Effect.none
            )

        ScmOrgRoleMapAddOnClick val ->
            let
                trimmedVal =
                    String.trim val

                parts =
                    Util.splitFirst "=" trimmedVal

                editableListForm =
                    model.scmOrgRoleMap
            in
            case parts of
                key :: value :: [] ->
                    let
                        trimmedKey =
                            String.trim key

                        trimmedValue =
                            String.trim value
                    in
                    if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                        ( model
                        , Effect.addAlertSuccess
                            { content = "SCM org role mapping must include a non-empty key and value."
                            , addToastIfUnique = False
                            , link = Nothing
                            }
                        )

                    else
                        let
                            currentMap =
                                RemoteData.unwrap Dict.empty (.scm >> .orgRoleMap) model.settings

                            effect =
                                if Dict.member trimmedKey currentMap then
                                    Effect.addAlertSuccess
                                        { content = "SCM org role mapping '" ++ trimmedKey ++ "' already exists."
                                        , addToastIfUnique = False
                                        , link = Nothing
                                        }

                                else
                                    let
                                        scmPayload =
                                            { defaultScmPayload
                                                | orgRoleMap = Just <| Dict.insert trimmedKey trimmedValue currentMap
                                            }

                                        payload =
                                            { defaultSettingsPayload
                                                | scm = Just scmPayload
                                            }

                                        body =
                                            Http.jsonBody <| Vela.encodeSettingsPayload payload
                                    in
                                    Effect.updateSettings
                                        { baseUrl = shared.velaAPIBaseURL
                                        , session = shared.session
                                        , onResponse =
                                            UpdateSettingsResponse
                                                { field = Vela.SCMOrgRoleMapAdd trimmedKey
                                                }
                                        , body = body
                                        }
                        in
                        ( { model | scmOrgRoleMap = { editableListForm | val = "" } }
                        , effect
                        )

                _ ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "SCM org role mapping must be in key=value format."
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

        ScmOrgRoleMapRemoveOnClick key ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .orgRoleMap) model.settings

                scmPayload =
                    { defaultScmPayload
                        | orgRoleMap = Just <| Dict.remove key currentMap
                    }

                payload =
                    { defaultSettingsPayload
                        | scm = Just scmPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.scmOrgRoleMap
            in
            ( { model | scmOrgRoleMap = { editableListForm | editing = Dict.remove key editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.SCMOrgRoleMapRemove key
                        }
                , body = body
                }
            )

        ScmOrgRoleMapEditOnClick options ->
            let
                editableListForm =
                    model.scmOrgRoleMap

                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .orgRoleMap) model.settings

                currentValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                currentEditValue =
                    options.id ++ "=" ++ currentValue
            in
            ( { model
                | scmOrgRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id currentEditValue editableListForm.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId scmOrgRoleMapHtmlId options.id }
            )

        ScmOrgRoleMapSaveOnClick options ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .orgRoleMap) model.settings

                existingValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                trimmedVal =
                    String.trim options.val

                parts =
                    Util.splitFirst "=" trimmedVal

                effect =
                    case parts of
                        key :: value :: [] ->
                            let
                                trimmedKey =
                                    String.trim key

                                trimmedValue =
                                    String.trim value

                                existingKey =
                                    options.id

                                isSame =
                                    trimmedKey == existingKey && trimmedValue == existingValue
                            in
                            if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                                Effect.addAlertSuccess
                                    { content = "SCM org role mapping must include a non-empty key and value."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else if isSame then
                                Effect.none

                            else if trimmedKey /= existingKey && Dict.member trimmedKey currentMap then
                                Effect.addAlertSuccess
                                    { content = "SCM org role mapping '" ++ trimmedKey ++ "' already exists."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else
                                let
                                    updatedMap =
                                        currentMap
                                            |> Dict.remove existingKey
                                            |> Dict.insert trimmedKey trimmedValue

                                    scmPayload =
                                        { defaultScmPayload
                                            | orgRoleMap = Just updatedMap
                                        }

                                    payload =
                                        { defaultSettingsPayload
                                            | scm = Just scmPayload
                                        }

                                    body =
                                        Http.jsonBody <| Vela.encodeSettingsPayload payload

                                    fromLabel =
                                        existingKey ++ "=" ++ existingValue

                                    toLabel =
                                        trimmedKey ++ "=" ++ trimmedValue
                                in
                                Effect.updateSettings
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse =
                                        UpdateSettingsResponse
                                            { field = Vela.SCMOrgRoleMapUpdate fromLabel toLabel
                                            }
                                    , body = body
                                    }

                        _ ->
                            Effect.addAlertSuccess
                                { content = "SCM org role mapping must be in key=value format."
                                , addToastIfUnique = False
                                , link = Nothing
                                }

                editableListForm =
                    model.scmOrgRoleMap
            in
            ( { model
                | scmOrgRoleMap =
                    { editableListForm
                        | editing = Dict.remove options.id editableListForm.editing
                    }
              }
            , effect
            )

        ScmOrgRoleMapEditOnInput options val ->
            let
                editableListForm =
                    model.scmOrgRoleMap
            in
            ( { model
                | scmOrgRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id val editableListForm.editing
                    }
              }
            , Effect.none
            )

        ScmRepoRoleMapOnInput val ->
            let
                editableListForm =
                    model.scmRepoRoleMap
            in
            ( { model
                | scmRepoRoleMap = { editableListForm | val = val }
              }
            , Effect.none
            )

        ScmRepoRoleMapAddOnClick val ->
            let
                trimmedVal =
                    String.trim val

                parts =
                    Util.splitFirst "=" trimmedVal

                editableListForm =
                    model.scmRepoRoleMap
            in
            case parts of
                key :: value :: [] ->
                    let
                        trimmedKey =
                            String.trim key

                        trimmedValue =
                            String.trim value
                    in
                    if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                        ( model
                        , Effect.addAlertSuccess
                            { content = "SCM repo role mapping must include a non-empty key and value."
                            , addToastIfUnique = False
                            , link = Nothing
                            }
                        )

                    else
                        let
                            currentMap =
                                RemoteData.unwrap Dict.empty (.scm >> .repoRoleMap) model.settings

                            effect =
                                if Dict.member trimmedKey currentMap then
                                    Effect.addAlertSuccess
                                        { content = "SCM repo role mapping '" ++ trimmedKey ++ "' already exists."
                                        , addToastIfUnique = False
                                        , link = Nothing
                                        }

                                else
                                    let
                                        scmPayload =
                                            { defaultScmPayload
                                                | repoRoleMap = Just <| Dict.insert trimmedKey trimmedValue currentMap
                                            }

                                        payload =
                                            { defaultSettingsPayload
                                                | scm = Just scmPayload
                                            }

                                        body =
                                            Http.jsonBody <| Vela.encodeSettingsPayload payload
                                    in
                                    Effect.updateSettings
                                        { baseUrl = shared.velaAPIBaseURL
                                        , session = shared.session
                                        , onResponse =
                                            UpdateSettingsResponse
                                                { field = Vela.SCMRepoRoleMapAdd trimmedKey
                                                }
                                        , body = body
                                        }
                        in
                        ( { model | scmRepoRoleMap = { editableListForm | val = "" } }
                        , effect
                        )

                _ ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "SCM repo role mapping must be in key=value format."
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

        ScmRepoRoleMapRemoveOnClick key ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .repoRoleMap) model.settings

                scmPayload =
                    { defaultScmPayload
                        | repoRoleMap = Just <| Dict.remove key currentMap
                    }

                payload =
                    { defaultSettingsPayload
                        | scm = Just scmPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.scmRepoRoleMap
            in
            ( { model | scmRepoRoleMap = { editableListForm | editing = Dict.remove key editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.SCMRepoRoleMapRemove key
                        }
                , body = body
                }
            )

        ScmRepoRoleMapEditOnClick options ->
            let
                editableListForm =
                    model.scmRepoRoleMap

                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .repoRoleMap) model.settings

                currentValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                currentEditValue =
                    options.id ++ "=" ++ currentValue
            in
            ( { model
                | scmRepoRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id currentEditValue editableListForm.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId scmRepoRoleMapHtmlId options.id }
            )

        ScmRepoRoleMapSaveOnClick options ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .repoRoleMap) model.settings

                existingValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                trimmedVal =
                    String.trim options.val

                parts =
                    Util.splitFirst "=" trimmedVal

                effect =
                    case parts of
                        key :: value :: [] ->
                            let
                                trimmedKey =
                                    String.trim key

                                trimmedValue =
                                    String.trim value

                                existingKey =
                                    options.id

                                isSame =
                                    trimmedKey == existingKey && trimmedValue == existingValue
                            in
                            if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                                Effect.addAlertSuccess
                                    { content = "SCM repo role mapping must include a non-empty key and value."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else if isSame then
                                Effect.none

                            else if trimmedKey /= existingKey && Dict.member trimmedKey currentMap then
                                Effect.addAlertSuccess
                                    { content = "SCM repo role mapping '" ++ trimmedKey ++ "' already exists."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else
                                let
                                    updatedMap =
                                        currentMap
                                            |> Dict.remove existingKey
                                            |> Dict.insert trimmedKey trimmedValue

                                    scmPayload =
                                        { defaultScmPayload
                                            | repoRoleMap = Just updatedMap
                                        }

                                    payload =
                                        { defaultSettingsPayload
                                            | scm = Just scmPayload
                                        }

                                    body =
                                        Http.jsonBody <| Vela.encodeSettingsPayload payload

                                    fromLabel =
                                        existingKey ++ "=" ++ existingValue

                                    toLabel =
                                        trimmedKey ++ "=" ++ trimmedValue
                                in
                                Effect.updateSettings
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse =
                                        UpdateSettingsResponse
                                            { field = Vela.SCMRepoRoleMapUpdate fromLabel toLabel
                                            }
                                    , body = body
                                    }

                        _ ->
                            Effect.addAlertSuccess
                                { content = "SCM repo role mapping must be in key=value format."
                                , addToastIfUnique = False
                                , link = Nothing
                                }

                editableListForm =
                    model.scmRepoRoleMap
            in
            ( { model
                | scmRepoRoleMap =
                    { editableListForm
                        | editing = Dict.remove options.id editableListForm.editing
                    }
              }
            , effect
            )

        ScmRepoRoleMapEditOnInput options val ->
            let
                editableListForm =
                    model.scmRepoRoleMap
            in
            ( { model
                | scmRepoRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id val editableListForm.editing
                    }
              }
            , Effect.none
            )

        ScmTeamRoleMapOnInput val ->
            let
                editableListForm =
                    model.scmTeamRoleMap
            in
            ( { model
                | scmTeamRoleMap = { editableListForm | val = val }
              }
            , Effect.none
            )

        ScmTeamRoleMapAddOnClick val ->
            let
                trimmedVal =
                    String.trim val

                parts =
                    Util.splitFirst "=" trimmedVal

                editableListForm =
                    model.scmTeamRoleMap
            in
            case parts of
                key :: value :: [] ->
                    let
                        trimmedKey =
                            String.trim key

                        trimmedValue =
                            String.trim value
                    in
                    if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                        ( model
                        , Effect.addAlertSuccess
                            { content = "SCM team role mapping must include a non-empty key and value."
                            , addToastIfUnique = False
                            , link = Nothing
                            }
                        )

                    else
                        let
                            currentMap =
                                RemoteData.unwrap Dict.empty (.scm >> .teamRoleMap) model.settings

                            effect =
                                if Dict.member trimmedKey currentMap then
                                    Effect.addAlertSuccess
                                        { content = "SCM team role mapping '" ++ trimmedKey ++ "' already exists."
                                        , addToastIfUnique = False
                                        , link = Nothing
                                        }

                                else
                                    let
                                        scmPayload =
                                            { defaultScmPayload
                                                | teamRoleMap = Just <| Dict.insert trimmedKey trimmedValue currentMap
                                            }

                                        payload =
                                            { defaultSettingsPayload
                                                | scm = Just scmPayload
                                            }

                                        body =
                                            Http.jsonBody <| Vela.encodeSettingsPayload payload
                                    in
                                    Effect.updateSettings
                                        { baseUrl = shared.velaAPIBaseURL
                                        , session = shared.session
                                        , onResponse =
                                            UpdateSettingsResponse
                                                { field = Vela.SCMTeamRoleMapAdd trimmedKey
                                                }
                                        , body = body
                                        }
                        in
                        ( { model | scmTeamRoleMap = { editableListForm | val = "" } }
                        , effect
                        )

                _ ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "SCM team role mapping must be in key=value format."
                        , addToastIfUnique = False
                        , link = Nothing
                        }
                    )

        ScmTeamRoleMapRemoveOnClick key ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .teamRoleMap) model.settings

                scmPayload =
                    { defaultScmPayload
                        | teamRoleMap = Just <| Dict.remove key currentMap
                    }

                payload =
                    { defaultSettingsPayload
                        | scm = Just scmPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.scmTeamRoleMap
            in
            ( { model | scmTeamRoleMap = { editableListForm | editing = Dict.remove key editableListForm.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.SCMTeamRoleMapRemove key
                        }
                , body = body
                }
            )

        ScmTeamRoleMapEditOnClick options ->
            let
                editableListForm =
                    model.scmTeamRoleMap

                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .teamRoleMap) model.settings

                currentValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                currentEditValue =
                    options.id ++ "=" ++ currentValue
            in
            ( { model
                | scmTeamRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id currentEditValue editableListForm.editing
                    }
              }
            , Effect.focusOn { target = saveButtonHtmlId scmTeamRoleMapHtmlId options.id }
            )

        ScmTeamRoleMapSaveOnClick options ->
            let
                currentMap =
                    RemoteData.unwrap Dict.empty (.scm >> .teamRoleMap) model.settings

                existingValue =
                    Maybe.withDefault "" <| Dict.get options.id currentMap

                trimmedVal =
                    String.trim options.val

                parts =
                    Util.splitFirst "=" trimmedVal

                effect =
                    case parts of
                        key :: value :: [] ->
                            let
                                trimmedKey =
                                    String.trim key

                                trimmedValue =
                                    String.trim value

                                existingKey =
                                    options.id

                                isSame =
                                    trimmedKey == existingKey && trimmedValue == existingValue
                            in
                            if String.isEmpty trimmedKey || String.isEmpty trimmedValue then
                                Effect.addAlertSuccess
                                    { content = "SCM team role mapping must include a non-empty key and value."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else if isSame then
                                Effect.none

                            else if trimmedKey /= existingKey && Dict.member trimmedKey currentMap then
                                Effect.addAlertSuccess
                                    { content = "SCM team role mapping '" ++ trimmedKey ++ "' already exists."
                                    , addToastIfUnique = False
                                    , link = Nothing
                                    }

                            else
                                let
                                    updatedMap =
                                        currentMap
                                            |> Dict.remove existingKey
                                            |> Dict.insert trimmedKey trimmedValue

                                    scmPayload =
                                        { defaultScmPayload
                                            | teamRoleMap = Just updatedMap
                                        }

                                    payload =
                                        { defaultSettingsPayload
                                            | scm = Just scmPayload
                                        }

                                    body =
                                        Http.jsonBody <| Vela.encodeSettingsPayload payload

                                    fromLabel =
                                        existingKey ++ "=" ++ existingValue

                                    toLabel =
                                        trimmedKey ++ "=" ++ trimmedValue
                                in
                                Effect.updateSettings
                                    { baseUrl = shared.velaAPIBaseURL
                                    , session = shared.session
                                    , onResponse =
                                        UpdateSettingsResponse
                                            { field = Vela.SCMTeamRoleMapUpdate fromLabel toLabel
                                            }
                                    , body = body
                                    }

                        _ ->
                            Effect.addAlertSuccess
                                { content = "SCM team role mapping must be in key=value format."
                                , addToastIfUnique = False
                                , link = Nothing
                                }

                editableListForm =
                    model.scmTeamRoleMap
            in
            ( { model
                | scmTeamRoleMap =
                    { editableListForm
                        | editing = Dict.remove options.id editableListForm.editing
                    }
              }
            , effect
            )

        ScmTeamRoleMapEditOnInput options val ->
            let
                editableListForm =
                    model.scmTeamRoleMap
            in
            ( { model
                | scmTeamRoleMap =
                    { editableListForm
                        | editing = Dict.insert options.id val editableListForm.editing
                    }
              }
            , Effect.none
            )

        -- DASHBOARDS
        MaxDashboardReposOnInput val ->
            ( { model
                | maxDashboardReposIn = Components.Form.handleNumberInputString model.maxDashboardReposIn val
              }
            , Effect.none
            )

        MaxDashboardReposOnUpdate val ->
            let
                payload =
                    { defaultSettingsPayload
                        | maxDashboardRepos = String.toInt val
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | maxDashboardReposIn = val
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.MaxDashboardRepos
                        }
                , body = body
                }
            )

        -- QUEUE LIMIT
        QueueRestartLimitOnInput val ->
            ( { model
                | queueRestartLimitIn = Components.Form.handleNumberInputString model.queueRestartLimitIn val
              }
            , Effect.none
            )

        QueueRestartLimitOnUpdate val ->
            let
                payload =
                    { defaultSettingsPayload
                        | queueRestartLimit = String.toInt val
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | queueRestartLimitIn = val
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.QueueRestartLimit
                        }
                , body = body
                }
            )

        -- SECRETS
        ToggleOrgSecrets enabled ->
            let
                payload =
                    { defaultSettingsPayload
                        | enableOrgSecrets = Just enabled
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | enableOrgSecrets = enabled
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.EnableOrgSecrets
                        }
                , body = body
                }
            )

        ToggleRepoSecrets enabled ->
            let
                payload =
                    { defaultSettingsPayload
                        | enableRepoSecrets = Just enabled
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | enableRepoSecrets = enabled
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.EnableRepoSecrets
                        }
                , body = body
                }
            )

        ToggleSharedSecrets enabled ->
            let
                payload =
                    { defaultSettingsPayload
                        | enableSharedSecrets = Just enabled
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | enableSharedSecrets = enabled
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.EnableSharedSecrets
                        }
                , body = body
                }
            )

        -- REFRESH
        Tick options ->
            ( model
            , Effect.getSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = RefreshSettingsResponse
                }
            )

        -- BLOCKED IMAGES
        BlockedImagesImageOnInput val ->
            let
                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | imageVal = val } }
            , Effect.none
            )

        BlockedImagesReasonOnInput val ->
            let
                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | reasonVal = val } }
            , Effect.none
            )

        BlockedImagesAddOnClick imageVal reasonVal ->
            let
                currentImages =
                    RemoteData.unwrap [] (.compiler >> .blockedImages) model.settings

                effect =
                    if not <| List.any (\r -> r.image == imageVal) currentImages then
                        let
                            newEntry =
                                Vela.ImageRestriction imageVal reasonVal

                            payload =
                                { defaultSettingsPayload
                                    | compiler =
                                        Just
                                            { defaultCompilerPayload
                                                | blockedImages = Just <| newEntry :: currentImages
                                            }
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.BlockedImageAdd imageVal
                                    }
                            , body = body
                            }

                    else
                        Effect.addAlertSuccess
                            { content = "Image '" ++ imageVal ++ "' already exists in the blocked images list."
                            , addToastIfUnique = False
                            , link = Nothing
                            }

                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | imageVal = "", reasonVal = "" } }
            , effect
            )

        BlockedImagesRemoveOnClick imageVal ->
            let
                payload =
                    { defaultSettingsPayload
                        | compiler =
                            Just
                                { defaultCompilerPayload
                                    | blockedImages =
                                        Just <|
                                            List.filter (\r -> r.image /= imageVal) <|
                                                RemoteData.unwrap [] (.compiler >> .blockedImages) model.settings
                                }
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | editing = Dict.remove imageVal form.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.BlockedImageRemove imageVal
                        }
                , body = body
                }
            )

        BlockedImagesEditOnClick options ->
            let
                currentReason =
                    RemoteData.unwrap [] (.compiler >> .blockedImages) model.settings
                        |> List.Extra.find (\r -> r.image == options.id)
                        |> Maybe.map .reason
                        |> Maybe.withDefault ""

                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | editing = Dict.insert options.id currentReason form.editing } }
            , Effect.focusOn { target = saveButtonHtmlId blockedImagesHtmlId options.id }
            )

        BlockedImagesSaveOnClick options ->
            let
                effect =
                    let
                        updatedImages =
                            RemoteData.unwrap [] (.compiler >> .blockedImages) model.settings
                                |> List.map
                                    (\r ->
                                        if r.image == options.id then
                                            { r | reason = options.val }

                                        else
                                            r
                                    )

                        payload =
                            { defaultSettingsPayload
                                | compiler =
                                    Just
                                        { defaultCompilerPayload
                                            | blockedImages = Just updatedImages
                                        }
                            }

                        body =
                            Http.jsonBody <| Vela.encodeSettingsPayload payload
                    in
                    Effect.updateSettings
                        { baseUrl = shared.velaAPIBaseURL
                        , session = shared.session
                        , onResponse =
                            UpdateSettingsResponse
                                { field = Vela.BlockedImageUpdate options.id options.val
                                }
                        , body = body
                        }

                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | editing = Dict.remove options.id form.editing } }
            , effect
            )

        BlockedImagesEditOnInput options val ->
            let
                form =
                    model.blockedImages
            in
            ( { model | blockedImages = { form | editing = Dict.insert options.id val form.editing } }
            , Effect.none
            )

        -- WARN IMAGES
        WarnImagesImageOnInput val ->
            let
                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | imageVal = val } }
            , Effect.none
            )

        WarnImagesReasonOnInput val ->
            let
                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | reasonVal = val } }
            , Effect.none
            )

        WarnImagesAddOnClick imageVal reasonVal ->
            let
                currentImages =
                    RemoteData.unwrap [] (.compiler >> .warnImages) model.settings

                effect =
                    if not <| List.any (\r -> r.image == imageVal) currentImages then
                        let
                            newEntry =
                                Vela.ImageRestriction imageVal reasonVal

                            payload =
                                { defaultSettingsPayload
                                    | compiler =
                                        Just
                                            { defaultCompilerPayload
                                                | warnImages = Just <| newEntry :: currentImages
                                            }
                                }

                            body =
                                Http.jsonBody <| Vela.encodeSettingsPayload payload
                        in
                        Effect.updateSettings
                            { baseUrl = shared.velaAPIBaseURL
                            , session = shared.session
                            , onResponse =
                                UpdateSettingsResponse
                                    { field = Vela.WarnImageAdd imageVal
                                    }
                            , body = body
                            }

                    else
                        Effect.addAlertSuccess
                            { content = "Image '" ++ imageVal ++ "' already exists in the warn images list."
                            , addToastIfUnique = False
                            , link = Nothing
                            }

                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | imageVal = "", reasonVal = "" } }
            , effect
            )

        WarnImagesRemoveOnClick imageVal ->
            let
                payload =
                    { defaultSettingsPayload
                        | compiler =
                            Just
                                { defaultCompilerPayload
                                    | warnImages =
                                        Just <|
                                            List.filter (\r -> r.image /= imageVal) <|
                                                RemoteData.unwrap [] (.compiler >> .warnImages) model.settings
                                }
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | editing = Dict.remove imageVal form.editing } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.WarnImageRemove imageVal
                        }
                , body = body
                }
            )

        WarnImagesEditOnClick options ->
            let
                currentReason =
                    RemoteData.unwrap [] (.compiler >> .warnImages) model.settings
                        |> List.Extra.find (\r -> r.image == options.id)
                        |> Maybe.map .reason
                        |> Maybe.withDefault ""

                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | editing = Dict.insert options.id currentReason form.editing } }
            , Effect.focusOn { target = saveButtonHtmlId warnImagesHtmlId options.id }
            )

        WarnImagesSaveOnClick options ->
            let
                effect =
                    let
                        updatedImages =
                            RemoteData.unwrap [] (.compiler >> .warnImages) model.settings
                                |> List.map
                                    (\r ->
                                        if r.image == options.id then
                                            { r | reason = options.val }

                                        else
                                            r
                                    )

                        payload =
                            { defaultSettingsPayload
                                | compiler =
                                    Just
                                        { defaultCompilerPayload
                                            | warnImages = Just updatedImages
                                        }
                            }

                        body =
                            Http.jsonBody <| Vela.encodeSettingsPayload payload
                    in
                    Effect.updateSettings
                        { baseUrl = shared.velaAPIBaseURL
                        , session = shared.session
                        , onResponse =
                            UpdateSettingsResponse
                                { field = Vela.WarnImageUpdate options.id options.val
                                }
                        , body = body
                        }

                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | editing = Dict.remove options.id form.editing } }
            , effect
            )

        WarnImagesEditOnInput options val ->
            let
                form =
                    model.warnImages
            in
            ( { model | warnImages = { form | editing = Dict.insert options.id val form.editing } }
            , Effect.none
            )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Interval.tickEveryFiveSeconds Tick



-- VIEW


{-| view : takes models, route, and creates the html for the page.
-}
view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    let
        disableSecretsControls =
            case model.settings of
                RemoteData.Success _ ->
                    False

                _ ->
                    True
    in
    { title = ""
    , body =
        [ div [ class "admin-settings" ]
            [ section
                [ class "settings"
                ]
                [ viewFieldHeader "Clone Image"
                , viewFieldDescription "The image to use with the embedded clone step."
                , viewFieldEnvKeyValue "VELA_CLONE_IMAGE"
                , div [ class "form-controls" ]
                    [ Components.Form.viewInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = cloneImageHtmlId
                        , val = model.cloneImage
                        , placeholder_ = "docker.io/target/vela-git:latest"
                        , classList_ = []
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = CloneImageOnInput
                        , disabled_ = False
                        , min = Nothing
                        , max = Nothing
                        , required = False
                        }
                    , Components.Form.viewButton
                        { id_ = cloneImageHtmlId ++ "-update"
                        , msg = CloneImageOnUpdate model.cloneImage
                        , text_ = "update"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            RemoteData.unwrap True
                                (\s ->
                                    String.isEmpty model.cloneImage
                                        || s.compiler.cloneImage
                                        == model.cloneImage
                                )
                                model.settings
                        }
                    ]
                , viewFieldPreviousValue model
                    (\s -> s.compiler.cloneImage)
                    (\ms -> Maybe.Extra.unwrap "" (.compiler >> .cloneImage) ms)
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Starlark Exec Limit"
                , viewFieldDescription "The number of executions allowed for Starlark scripts."
                , viewFieldEnvKeyValue "VELA_COMPILER_STARLARK_EXEC_LIMIT"
                , viewFieldLimits <| text <| numberBoundsToString starlarkExecLimitMin <| starlarkExecLimitMax shared
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = starlarkExecLimitHtmlId
                        , val = model.starlarkExecLimitIn
                        , placeholder_ = numberBoundsToString starlarkExecLimitMin <| starlarkExecLimitMax shared
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = StarlarkExecLimitOnInput
                        , disabled_ = False
                        , min = Just starlarkExecLimitMin
                        , max = Just <| starlarkExecLimitMax shared
                        , required = False
                        }
                    , Components.Form.viewButton
                        { id_ = starlarkExecLimitHtmlId ++ "-update"
                        , msg = StarlarkExecLimitOnUpdate model.starlarkExecLimitIn
                        , text_ = "update"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            RemoteData.unwrap True
                                (\s ->
                                    case String.toInt model.starlarkExecLimitIn of
                                        Just limit ->
                                            limit
                                                == s.compiler.starlarkExecLimit
                                                || (limit < starlarkExecLimitMin)
                                                || (limit > starlarkExecLimitMax shared)

                                        Nothing ->
                                            True
                                )
                                model.settings
                        }
                    ]
                , viewFieldPreviousValue model
                    (\s -> String.fromInt s.compiler.starlarkExecLimit)
                    (\ms -> Maybe.Extra.unwrap "" (.compiler >> .starlarkExecLimit >> String.fromInt) ms)
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Template Depth"
                , viewFieldDescription "The depth allowed for nested template references."
                , viewFieldEnvKeyValue "VELA_TEMPLATE_DEPTH"
                , viewFieldLimits <| text <| numberBoundsToString templateDepthLimitMin templateDepthLimitMax
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "template-depth"
                        , val = model.templateDepthIn
                        , placeholder_ = numberBoundsToString templateDepthLimitMin templateDepthLimitMax
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = TemplateDepthOnInput
                        , disabled_ = False
                        , min = Just templateDepthLimitMin
                        , max = Just templateDepthLimitMax
                        , required = False
                        }
                    , Components.Form.viewButton
                        { id_ = "template-depth-update"
                        , msg = TemplateDepthOnUpdate model.templateDepthIn
                        , text_ = "update"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            RemoteData.unwrap True
                                (\s ->
                                    case String.toInt model.templateDepthIn of
                                        Just limit ->
                                            limit
                                                == s.compiler.templateDepth
                                                || (limit < templateDepthLimitMin)
                                                || (limit > templateDepthLimitMax)

                                        Nothing ->
                                            True
                                )
                                model.settings
                        }
                    ]
                , viewFieldPreviousValue model
                    (\s -> String.fromInt s.compiler.templateDepth)
                    (\ms -> Maybe.Extra.unwrap "" (.compiler >> .templateDepth >> String.fromInt) ms)
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Max Dashboard Repos"
                , viewFieldDescription "The maximum number of repos a dashboard can have."
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "max-dashboard-repos"
                        , val = model.maxDashboardReposIn
                        , placeholder_ = ""
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = MaxDashboardReposOnInput
                        , disabled_ = False
                        , min = Just 0
                        , max = Just 100
                        , required = False
                        }
                    , Components.Form.viewButton
                        { id_ = "max-dashboard-repos-update"
                        , msg = MaxDashboardReposOnUpdate model.maxDashboardReposIn
                        , text_ = "update"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            RemoteData.unwrap True
                                (\s ->
                                    case String.toInt model.maxDashboardReposIn of
                                        Just limit ->
                                            limit
                                                == s.maxDashboardRepos
                                                || (limit < 1)
                                                || (limit > 99)

                                        Nothing ->
                                            True
                                )
                                model.settings
                        }
                    ]
                , viewFieldPreviousValue model
                    (\s -> String.fromInt s.maxDashboardRepos)
                    (\ms -> Maybe.Extra.unwrap "" (.maxDashboardRepos >> String.fromInt) ms)
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Queue Restart Limit"
                , viewFieldDescription "Users cannot restart builds when the queue reaches this limit. Set to '0' to remove this restriction."
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "queue-restart-limit"
                        , val = model.queueRestartLimitIn
                        , placeholder_ = ""
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = QueueRestartLimitOnInput
                        , disabled_ = False
                        , min = Just 0
                        , max = Just 100
                        , required = False
                        }
                    , Components.Form.viewButton
                        { id_ = "queue-restart-limit-update"
                        , msg = QueueRestartLimitOnUpdate model.queueRestartLimitIn
                        , text_ = "update"
                        , classList_ =
                            [ ( "-outline", True )
                            ]
                        , disabled_ =
                            RemoteData.unwrap True
                                (\s ->
                                    case String.toInt model.queueRestartLimitIn of
                                        Just limit ->
                                            limit
                                                == s.queueRestartLimit
                                                || (limit < 1)
                                                || (limit > 99)

                                        Nothing ->
                                            True
                                )
                                model.settings
                        }
                    ]
                , viewFieldPreviousValue model
                    (\s -> String.fromInt s.queueRestartLimit)
                    (\ms -> Maybe.Extra.unwrap "" (.queueRestartLimit >> String.fromInt) ms)
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Secrets"
                , viewFieldDescription "Toggle which secret types can be created. Disabling a type only prevents new secrets from being created."
                , viewFieldEnvKeyValue "VELA_ENABLE_ORG_SECRETS"
                , viewFieldEnvKeyValue "VELA_ENABLE_REPO_SECRETS"
                , viewFieldEnvKeyValue "VELA_ENABLE_SHARED_SECRETS"
                , div [ class "form-controls", class "-two-col" ]
                    [ Components.Form.viewCheckbox
                        { id_ = "admin-secrets"
                        , title = "Organization"
                        , subtitle = Nothing
                        , field = "org"
                        , state = model.enableOrgSecrets
                        , wrapperClassList = []
                        , msg = ToggleOrgSecrets
                        , disabled_ = disableSecretsControls
                        }
                    , Components.Form.viewCheckbox
                        { id_ = "admin-secrets"
                        , title = "Repository"
                        , subtitle = Nothing
                        , field = "repo"
                        , state = model.enableRepoSecrets
                        , wrapperClassList = []
                        , msg = ToggleRepoSecrets
                        , disabled_ = disableSecretsControls
                        }
                    , Components.Form.viewCheckbox
                        { id_ = "admin-secrets"
                        , title = "Shared"
                        , subtitle = Nothing
                        , field = "shared"
                        , state = model.enableSharedSecrets
                        , wrapperClassList = []
                        , msg = ToggleSharedSecrets
                        , disabled_ = disableSecretsControls
                        }
                    ]
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Queue Routes"
                , viewFieldDescription "The queue routes used when queuing builds."
                , viewFieldEnvKeyValue "VELA_QUEUE_ROUTES"
                , Components.Form.viewEditableList
                    { id_ = queueRoutesHtmlId
                    , webdata = model.settings
                    , toItems = .queue >> .routes
                    , toId = identity
                    , toLabel = identity
                    , addProps =
                        Just
                            { placeholder_ = "vela"
                            , addOnInputMsg = QueueRoutesOnInput
                            , addOnClickMsg = QueueRoutesAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| queueRoutesHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No routes set"
                    , form = model.queueRoutes
                    , itemEditOnClickMsg = QueueRoutesEditOnClick
                    , itemSaveOnClickMsg = QueueRoutesSaveOnClick
                    , itemEditOnInputMsg = QueueRoutesEditOnInput
                    , itemRemoveOnClickMsg = QueueRoutesRemoveOnClick
                    }
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Repo Allowlist"
                , viewFieldDescription "The repos permitted to use Vela."
                , viewFieldEnvKeyValue "VELA_REPO_ALLOWLIST"
                , Components.Form.viewEditableList
                    { id_ = repoAllowlistHtmlId
                    , webdata = model.settings
                    , toItems = .repoAllowlist
                    , toId = \r -> r
                    , toLabel =
                        \r ->
                            if r == "*" then
                                r ++ " (all repos)"

                            else
                                r
                    , addProps =
                        Just
                            { placeholder_ = "octocat/hello-world"
                            , addOnInputMsg = RepoAllowlistOnInput
                            , addOnClickMsg = RepoAllowlistAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| repoAllowlistHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No repos allowed"
                    , form = model.repoAllowlist
                    , itemEditOnClickMsg = RepoAllowlistEditOnClick
                    , itemSaveOnClickMsg = RepoAllowlistSaveOnClick
                    , itemEditOnInputMsg = RepoAllowlistEditOnInput
                    , itemRemoveOnClickMsg = RepoAllowlistRemoveOnClick
                    }
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Schedule Allowlist"
                , viewFieldDescription "The repos permitted to use schedules."
                , viewFieldEnvKeyValue "VELA_SCHEDULE_ALLOWLIST"
                , Components.Form.viewEditableList
                    { id_ = scheduleAllowlistHtmlId
                    , webdata = model.settings
                    , toItems = .scheduleAllowlist
                    , toId = \r -> r
                    , toLabel =
                        \r ->
                            if r == "*" then
                                r ++ " (all repos)"

                            else
                                r
                    , addProps =
                        Just
                            { placeholder_ = "octocat/hello-world"
                            , addOnInputMsg = ScheduleAllowlistOnInput
                            , addOnClickMsg = ScheduleAllowlistAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| scheduleAllowlistHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No repos allowed"
                    , form = model.scheduleAllowlist
                    , itemEditOnClickMsg = ScheduleAllowlistEditOnClick
                    , itemSaveOnClickMsg = ScheduleAllowlistSaveOnClick
                    , itemEditOnInputMsg = ScheduleAllowlistEditOnInput
                    , itemRemoveOnClickMsg = ScheduleAllowlistRemoveOnClick
                    }
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "SCM Org Role Map"
                , viewFieldDescription "Role mapping used for SCM organization membership."
                , viewFieldEnvKeyValue "VELA_SCM_ORG_ROLE_MAP"
                , Components.Form.viewEditableList
                    { id_ = scmOrgRoleMapHtmlId
                    , webdata = model.settings
                    , toItems = .scm >> .orgRoleMap >> Dict.toList
                    , toId = Tuple.first
                    , toLabel = \( key, value ) -> key ++ "=" ++ value
                    , addProps =
                        Just
                            { placeholder_ = "org=admin"
                            , addOnInputMsg = ScmOrgRoleMapOnInput
                            , addOnClickMsg = ScmOrgRoleMapAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| scmOrgRoleMapHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No org role mappings"
                    , form = model.scmOrgRoleMap
                    , itemEditOnClickMsg = ScmOrgRoleMapEditOnClick
                    , itemSaveOnClickMsg = ScmOrgRoleMapSaveOnClick
                    , itemEditOnInputMsg = ScmOrgRoleMapEditOnInput
                    , itemRemoveOnClickMsg = ScmOrgRoleMapRemoveOnClick
                    }
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "SCM Repo Role Map"
                , viewFieldDescription "Role mapping used for SCM repository access."
                , viewFieldEnvKeyValue "VELA_SCM_REPO_ROLE_MAP"
                , Components.Form.viewEditableList
                    { id_ = scmRepoRoleMapHtmlId
                    , webdata = model.settings
                    , toItems = .scm >> .repoRoleMap >> Dict.toList
                    , toId = Tuple.first
                    , toLabel = \( key, value ) -> key ++ "=" ++ value
                    , addProps =
                        Just
                            { placeholder_ = "octocat/hello-world=write"
                            , addOnInputMsg = ScmRepoRoleMapOnInput
                            , addOnClickMsg = ScmRepoRoleMapAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| scmRepoRoleMapHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No repo role mappings"
                    , form = model.scmRepoRoleMap
                    , itemEditOnClickMsg = ScmRepoRoleMapEditOnClick
                    , itemSaveOnClickMsg = ScmRepoRoleMapSaveOnClick
                    , itemEditOnInputMsg = ScmRepoRoleMapEditOnInput
                    , itemRemoveOnClickMsg = ScmRepoRoleMapRemoveOnClick
                    }
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "SCM Team Role Map"
                , viewFieldDescription "Role mapping used for SCM team membership."
                , viewFieldEnvKeyValue "VELA_SCM_TEAM_ROLE_MAP"
                , Components.Form.viewEditableList
                    { id_ = scmTeamRoleMapHtmlId
                    , webdata = model.settings
                    , toItems = .scm >> .teamRoleMap >> Dict.toList
                    , toId = Tuple.first
                    , toLabel = \( key, value ) -> key ++ "=" ++ value
                    , addProps =
                        Just
                            { placeholder_ = "team=admin"
                            , addOnInputMsg = ScmTeamRoleMapOnInput
                            , addOnClickMsg = ScmTeamRoleMapAddOnClick
                            }
                    , viewHttpError =
                        \error ->
                            span [ Util.testAttribute <| scmTeamRoleMapHtmlId ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                    , viewNoItems = text "No team role mappings"
                    , form = model.scmTeamRoleMap
                    , itemEditOnClickMsg = ScmTeamRoleMapEditOnClick
                    , itemSaveOnClickMsg = ScmTeamRoleMapSaveOnClick
                    , itemEditOnInputMsg = ScmTeamRoleMapEditOnInput
                    , itemRemoveOnClickMsg = ScmTeamRoleMapRemoveOnClick
                    }
                ]
            , viewImageRestrictionSection
                { id_ = blockedImagesHtmlId
                , header = "Blocked Images"
                , description = "Image patterns that are blocked from use in pipelines. Builds using a blocked image will fail to compile."
                , imagePlaceholder = "docker.io/org/image:*"
                , reasonPlaceholder = "This image is no longer supported."
                , form = model.blockedImages
                , webdata = model.settings
                , toItems = .compiler >> .blockedImages
                , imageOnInputMsg = BlockedImagesImageOnInput
                , reasonOnInputMsg = BlockedImagesReasonOnInput
                , addOnClickMsg = BlockedImagesAddOnClick
                , itemEditOnClickMsg = BlockedImagesEditOnClick
                , itemSaveOnClickMsg = BlockedImagesSaveOnClick
                , itemEditOnInputMsg = BlockedImagesEditOnInput
                , itemRemoveOnClickMsg = BlockedImagesRemoveOnClick
                }
            , viewImageRestrictionSection
                { id_ = warnImagesHtmlId
                , header = "Warn Images"
                , description = "Image patterns that trigger a warning on the Pipeline tab when used in a pipeline."
                , imagePlaceholder = "docker.io/org/image:*"
                , reasonPlaceholder = "This image will be blocked in a future release."
                , form = model.warnImages
                , webdata = model.settings
                , toItems = .compiler >> .warnImages
                , imageOnInputMsg = WarnImagesImageOnInput
                , reasonOnInputMsg = WarnImagesReasonOnInput
                , addOnClickMsg = WarnImagesAddOnClick
                , itemEditOnClickMsg = WarnImagesEditOnClick
                , itemSaveOnClickMsg = WarnImagesSaveOnClick
                , itemEditOnInputMsg = WarnImagesEditOnInput
                , itemRemoveOnClickMsg = WarnImagesRemoveOnClick
                }
            ]
        , case model.settings of
            RemoteData.Success settings ->
                if settings.updatedAt > 0 then
                    let
                        updatedAt =
                            Util.humanReadableDateTimeWithDefault shared.zone settings.updatedAt
                    in
                    p []
                        [ text <| "Last updated on "
                        , i [] [ text updatedAt ]
                        , text " by "
                        , i [] [ text settings.updatedBy ]
                        , text "."
                        ]

                else
                    text ""

            _ ->
                text ""
        ]
    }


{-| viewFieldHeader : renders header view for a settings field
-}
viewFieldHeader : String -> Html Msg
viewFieldHeader title =
    h2 [ class "settings-title" ]
        [ text title ]


{-| viewFieldDescription : renders description view for a settings field
-}
viewFieldDescription : String -> Html Msg
viewFieldDescription description =
    p [ class "settings-description" ]
        [ text description
        ]


{-| viewFieldEnvKeyValue : renders env key view for a settings field
-}
viewFieldEnvKeyValue : String -> Html Msg
viewFieldEnvKeyValue envKey =
    p [ class "settings-info" ]
        [ strong [] [ text "Env: " ]
        , span [] [ text envKey ]
        ]


{-| viewFieldPreviousValue : renders previous value for a settings field
-}
viewFieldPreviousValue : Model -> (Vela.PlatformSettings -> String) -> (Maybe Vela.PlatformSettings -> String) -> Html Msg
viewFieldPreviousValue model toCurr toPrev =
    p [ class "settings-previous-value" ] <|
        case model.settings of
            RemoteData.Success settings ->
                if toPrev model.originalSettings /= toCurr settings then
                    [ strong [] [ text "Before: " ]
                    , span [] [ text (toPrev model.originalSettings) ]
                    ]

                else
                    [ text "" ]

            _ ->
                [ text "" ]


{-| viewFieldLimits : renders limits or restrictions for a settings field
-}
viewFieldLimits : Html Msg -> Html Msg
viewFieldLimits viewLimits =
    p [ class "settings-info" ]
        [ strong [] [ text "Restrictions: " ]
        , span [] [ viewLimits ]
        ]


{-| numberBoundsToString : converts number bounds for a settings field to string
-}
numberBoundsToString : Int -> Int -> String
numberBoundsToString min max =
    String.fromInt min ++ " <= value <= " ++ String.fromInt max



-- HTML IDENTIFIERS


{-| cloneImageHtmlId : returns reusable id for clone image
-}
cloneImageHtmlId : String
cloneImageHtmlId =
    "clone-image"


{-| starlarkExecLimitHtmlId : returns reusable id for starlark exec limit
-}
starlarkExecLimitHtmlId : String
starlarkExecLimitHtmlId =
    "starlark-exec-limit"


{-| queueRoutesHtmlId : returns reusable id for queue routes
-}
queueRoutesHtmlId : String
queueRoutesHtmlId =
    "queue-routes"


{-| repoAllowlistHtmlId : returns reusable id for repo allowlist
-}
repoAllowlistHtmlId : String
repoAllowlistHtmlId =
    "repo-allowlist"


{-| scheduleAllowlistHtmlId : returns reusable id for schedule allowlist
-}
scheduleAllowlistHtmlId : String
scheduleAllowlistHtmlId =
    "schedule-allowlist"


{-| scmOrgRoleMapHtmlId : returns reusable id for SCM org role map
-}
scmOrgRoleMapHtmlId : String
scmOrgRoleMapHtmlId =
    "scm-org-role-map"


{-| scmRepoRoleMapHtmlId : returns reusable id for SCM repo role map
-}
scmRepoRoleMapHtmlId : String
scmRepoRoleMapHtmlId =
    "scm-repo-role-map"


{-| scmTeamRoleMapHtmlId : returns reusable id for SCM team role map
-}
scmTeamRoleMapHtmlId : String
scmTeamRoleMapHtmlId =
    "scm-team-role-map"


{-| blockedImagesHtmlId : returns reusable id for blocked images
-}
blockedImagesHtmlId : String
blockedImagesHtmlId =
    "blocked-images"


{-| warnImagesHtmlId : returns reusable id for warn images
-}
warnImagesHtmlId : String
warnImagesHtmlId =
    "warn-images"


{-| saveButtonHtmlId : returns reusable id for save button
-}
saveButtonHtmlId : String -> String -> String
saveButtonHtmlId base id =
    base ++ "-save-" ++ id



-- LIMITS


{-| templateDepthLimitMin : returns the minimum value for the template depth limit
-}
templateDepthLimitMin : Int
templateDepthLimitMin =
    1


{-| templateDepthLimitMax : returns the maximum value for the template depth limit
-}
templateDepthLimitMax : Int
templateDepthLimitMax =
    100


{-| starlarkExecLimitMin : returns the minimum value for the starlark exec limit
-}
starlarkExecLimitMin : Int
starlarkExecLimitMin =
    1


{-| starlarkExecLimitMax : returns the maximum value for the starlark exec limit
-}
starlarkExecLimitMax : Shared.Model -> Int
starlarkExecLimitMax shared =
    shared.velaMaxStarlarkExecLimit


{-| viewImageRestrictionSection : renders a settings section for managing an image restriction list
(blocked or warn). Each entry has an image pattern and an optional reason string.
-}
viewImageRestrictionSection :
    { id_ : String
    , header : String
    , description : String
    , imagePlaceholder : String
    , reasonPlaceholder : String
    , form : ImageRestrictionListForm
    , webdata : WebData Vela.PlatformSettings
    , toItems : Vela.PlatformSettings -> List Vela.ImageRestriction
    , imageOnInputMsg : String -> Msg
    , reasonOnInputMsg : String -> Msg
    , addOnClickMsg : String -> String -> Msg
    , itemEditOnClickMsg : { id : String } -> Msg
    , itemSaveOnClickMsg : { id : String, val : String } -> Msg
    , itemEditOnInputMsg : { id : String } -> String -> Msg
    , itemRemoveOnClickMsg : String -> Msg
    }
    -> Html Msg
viewImageRestrictionSection props =
    let
        target =
            String.join "-" [ "editable-list", props.id_ ]
    in
    section
        [ class "settings"
        ]
        [ viewFieldHeader props.header
        , viewFieldDescription props.description
        , div [ class "form-controls" ]
            [ Components.Form.viewInput
                { title = Nothing
                , subtitle = Nothing
                , id_ = target ++ "-image-add"
                , val = props.form.imageVal
                , placeholder_ = props.imagePlaceholder
                , classList_ = []
                , wrapperClassList = [ ( "-wide", True ) ]
                , rows_ = Nothing
                , wrap_ = Nothing
                , msg = props.imageOnInputMsg
                , disabled_ = False
                , min = Nothing
                , max = Nothing
                , required = False
                }
            , Components.Form.viewInput
                { title = Nothing
                , subtitle = Nothing
                , id_ = target ++ "-reason-add"
                , val = props.form.reasonVal
                , placeholder_ = props.reasonPlaceholder
                , classList_ = []
                , wrapperClassList = [ ( "-wide", True ) ]
                , rows_ = Nothing
                , wrap_ = Nothing
                , msg = props.reasonOnInputMsg
                , disabled_ = False
                , min = Nothing
                , max = Nothing
                , required = False
                }
            , Components.Form.viewButton
                { id_ = target ++ "-add"
                , msg = props.addOnClickMsg props.form.imageVal props.form.reasonVal
                , text_ = "add"
                , classList_ = [ ( "-outline", True ) ]
                , disabled_ =
                    String.isEmpty props.form.imageVal
                        || not (RemoteData.isSuccess props.webdata)
                }
            ]
        , div
            [ class "editable-list"
            , Util.testAttribute target
            ]
            [ ul [] <|
                case props.webdata of
                    RemoteData.Success settings ->
                        let
                            items =
                                props.toItems settings
                        in
                        if List.isEmpty items then
                            [ li [ Util.testAttribute <| target ++ "-no-items" ]
                                [ text "No images configured" ]
                            ]

                        else
                            List.map (viewImageRestrictionItem props) items

                    RemoteData.Failure error ->
                        [ li []
                            [ span [ Util.testAttribute <| target ++ "-error" ]
                                [ text <|
                                    case error of
                                        Http.BadStatus statusCode ->
                                            case statusCode of
                                                401 ->
                                                    "No settings found"

                                                _ ->
                                                    "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                        _ ->
                                            "No settings found"
                                ]
                            ]
                        ]

                    _ ->
                        [ li [] [ Components.Loading.viewSmallLoader ] ]
            ]
        ]


{-| viewImageRestrictionItem : renders a single image restriction list item with edit-in-place for the reason field.
-}
viewImageRestrictionItem :
    { a
        | id_ : String
        , itemEditOnClickMsg : { id : String } -> Msg
        , itemSaveOnClickMsg : { id : String, val : String } -> Msg
        , itemEditOnInputMsg : { id : String } -> String -> Msg
        , itemRemoveOnClickMsg : String -> Msg
        , form : ImageRestrictionListForm
    }
    -> Vela.ImageRestriction
    -> Html Msg
viewImageRestrictionItem props item =
    let
        target =
            String.join "-" [ "editable-list", "item", item.image ]

        editing =
            Dict.get item.image props.form.editing
    in
    li [ Util.testAttribute target ]
        [ case editing of
            Just reasonVal ->
                Components.Form.viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = target
                    , val = reasonVal
                    , placeholder_ = item.image
                    , wrapperClassList = []
                    , classList_ = []
                    , rows_ = Nothing
                    , wrap_ = Nothing
                    , msg = props.itemEditOnInputMsg { id = item.image }
                    , disabled_ = False
                    , min = Nothing
                    , max = Nothing
                    , required = False
                    }

            Nothing ->
                span []
                    [ text item.image
                    , if String.isEmpty item.reason then
                        text ""

                      else
                        span [ class "settings-info" ]
                            [ text <| " — " ++ item.reason ]
                    ]
        , span [] <|
            case editing of
                Just reasonVal ->
                    [ Components.Form.viewButton
                        { id_ = saveButtonHtmlId props.id_ item.image
                        , msg = props.itemSaveOnClickMsg { id = item.image, val = reasonVal }
                        , text_ = "save"
                        , classList_ = [ ( "-icon", True ) ]
                        , disabled_ = False
                        }
                    , Components.Form.viewButton
                        { id_ = target ++ "-remove"
                        , msg = props.itemRemoveOnClickMsg item.image
                        , text_ = "remove"
                        , classList_ = [ ( "-icon", True ) ]
                        , disabled_ = False
                        }
                    ]

                Nothing ->
                    [ Components.Form.viewButton
                        { id_ = target ++ "-edit"
                        , msg = props.itemEditOnClickMsg { id = item.image }
                        , text_ = "edit"
                        , classList_ = [ ( "-icon", True ) ]
                        , disabled_ = False
                        }
                    ]
        ]

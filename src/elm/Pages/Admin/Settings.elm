{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Settings exposing (Model, Msg, page)

import Auth
import Components.Form
import Dict
import Effect exposing (Effect)
import Html exposing (Html, button, div, h2, p, section, span, strong, text)
import Html.Attributes exposing (class, classList, disabled)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Json.Decode exposing (Error(..))
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultCompilerPayload, defaultQueuePayload, defaultSettingsPayload)
import View exposing (View)


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


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default_Admin
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "Get Settings"
              , content = "vela view settings"
              , docs = Just "cli/admin/settings/get"
              }
            ]
        , crumbs =
            [ ( "Admin", Nothing )
            ]
        }



-- INIT


type alias Model =
    { settings : WebData Vela.PlatformSettings
    , exported : WebData String
    , cloneImage : String
    , starlarkExecLimit : Maybe Int
    , templateDepth : Maybe Int
    , queueRoutes : Components.Form.EditableListForm
    , repoAllowlist : Components.Form.EditableListForm
    , scheduleAllowlist : Components.Form.EditableListForm
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { settings = RemoteData.Loading
      , exported = RemoteData.Loading
      , cloneImage = ""
      , starlarkExecLimit = Nothing
      , templateDepth = Nothing
      , queueRoutes = { val = "", editing = Dict.empty }
      , repoAllowlist = { val = "", editing = Dict.empty }
      , scheduleAllowlist = { val = "", editing = Dict.empty }
      }
    , Effect.getSettings
        { baseUrl = shared.velaAPIBaseURL
        , session = shared.session
        , onResponse = GetSettingsResponse
        }
    )



-- UPDATE


type Msg
    = -- SETTINGS
      GetSettingsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ))
    | UpdateSettingsResponse { field : Vela.PlatformSettingsFieldUpdate } (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.PlatformSettings ))
      -- COMPILER
    | CloneImageOnInput String
    | CloneImageUpdate String
    | StarlarkExecLimitOnInput String
    | StarlarkExecLimitOnUpdate (Maybe Int)
    | TemplateDepthOnInput String
    | TemplateDepthOnUpdate (Maybe Int)
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


update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetSettingsResponse response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | settings = RemoteData.Success settings
                        , cloneImage = settings.compiler.cloneImage
                        , starlarkExecLimit = Just settings.compiler.starlarkExecLimit
                        , templateDepth = Just settings.compiler.templateDepth
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
                    ( { model | settings = Errors.toFailure error }
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

        CloneImageUpdate val ->
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
            ( model
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
            ( case String.toInt val of
                Just val_ ->
                    { model
                        | starlarkExecLimit = Just val_
                    }

                Nothing ->
                    model
            , Effect.none
            )

        StarlarkExecLimitOnUpdate val ->
            let
                compilerPayload =
                    { defaultCompilerPayload
                        | starlarkExecLimit = val
                    }

                payload =
                    { defaultSettingsPayload
                        | compiler = Just compilerPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( model
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
            ( case String.toInt val of
                Just val_ ->
                    { model
                        | templateDepth = Just val_
                    }

                Nothing ->
                    model
            , Effect.none
            )

        TemplateDepthOnUpdate val ->
            let
                compilerPayload =
                    { defaultCompilerPayload
                        | templateDepth = val
                    }

                payload =
                    { defaultSettingsPayload
                        | compiler = Just compilerPayload
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( model
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
                queuePayload =
                    { defaultQueuePayload
                        | routes = Just <| List.Extra.unique <| val :: RemoteData.unwrap [] (.queue >> .routes) model.settings
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
            ( { model | queueRoutes = { editableListForm | val = "" } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.QueueRouteAdd val
                        }
                , body = body
                }
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
            , Effect.focusOn { target = saveButtonId queueRoutesId options.id }
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
                payload =
                    { defaultSettingsPayload
                        | repoAllowlist = Just <| List.Extra.unique <| val :: RemoteData.unwrap [] .repoAllowlist model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.repoAllowlist
            in
            ( { model | repoAllowlist = { editableListForm | val = "" } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.RepoAllowlistAdd val
                        }
                , body = body
                }
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
            , Effect.focusOn { target = saveButtonId repoAllowlistId options.id }
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
                payload =
                    { defaultSettingsPayload
                        | scheduleAllowlist = Just <| List.Extra.unique <| val :: RemoteData.unwrap [] .scheduleAllowlist model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload

                editableListForm =
                    model.scheduleAllowlist
            in
            ( { model | scheduleAllowlist = { editableListForm | val = "" } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse =
                    UpdateSettingsResponse
                        { field = Vela.ScheduleAllowlistAdd val
                        }
                , body = body
                }
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
            , Effect.focusOn { target = saveButtonId scheduleAllowlistId options.id }
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
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
                        , id_ = "clone-image"
                        , val = model.cloneImage
                        , placeholder_ = "docker.io/target/vela-git:latest"
                        , classList_ = []
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = CloneImageOnInput
                        , disabled_ = False
                        }
                    , button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| CloneImageUpdate model.cloneImage
                        , disabled <|
                            RemoteData.unwrap True
                                (\s ->
                                    String.isEmpty model.cloneImage
                                        || s.compiler.cloneImage
                                        == model.cloneImage
                                )
                                model.settings
                        ]
                        [ text "update" ]
                    ]
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Starlark Exec Limit"
                , viewFieldDescription "The number of executions allowed for Starlark scripts."
                , viewFieldEnvKeyValue "VELA_COMPILER_STARLARK_EXEC_LIMIT"
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "starlark-exec-limit"
                        , val = model.starlarkExecLimit
                        , placeholder_ = ""
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = StarlarkExecLimitOnInput
                        , disabled_ = False
                        , min = 1
                        , max = 10000
                        }
                    , button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| StarlarkExecLimitOnUpdate model.starlarkExecLimit
                        , disabled <|
                            RemoteData.unwrap True
                                (\s ->
                                    case model.starlarkExecLimit of
                                        Just limit ->
                                            limit == s.compiler.starlarkExecLimit

                                        Nothing ->
                                            True
                                )
                                model.settings
                        ]
                        [ text "update" ]
                    ]
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Template Depth"
                , viewFieldDescription "The depth allowed for nested template references."
                , viewFieldEnvKeyValue "VELA_TEMPLATE_DEPTH"
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "template-depth"
                        , val = model.templateDepth
                        , placeholder_ = ""
                        , wrapperClassList = [ ( "-wide", True ) ]
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = TemplateDepthOnInput
                        , disabled_ = False
                        , min = 1
                        , max = 100
                        }
                    , button
                        [ classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| TemplateDepthOnUpdate model.templateDepth
                        , disabled <|
                            RemoteData.unwrap True
                                (\s ->
                                    case model.templateDepth of
                                        Just limit ->
                                            limit == s.compiler.templateDepth

                                        Nothing ->
                                            True
                                )
                                model.settings
                        ]
                        [ text "update" ]
                    ]
                ]
            , section
                [ class "settings"
                ]
                [ viewFieldHeader "Queue Routes"
                , viewFieldDescription "The queue routes used when queuing builds."
                , viewFieldEnvKeyValue "VELA_QUEUE_ROUTES"
                , Components.Form.viewEditableList
                    { id_ = queueRoutesId
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
                            span [ Util.testAttribute <| queueRoutesId ++ "-error" ]
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
                    { id_ = repoAllowlistId
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
                            span [ Util.testAttribute <| repoAllowlistId ++ "-error" ]
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
                    { id_ = scheduleAllowlistId
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
                            span [ Util.testAttribute <| scheduleAllowlistId ++ "-error" ]
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
            ]
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
    p [ class "settings-env-key" ]
        [ strong [] [ text "Env: " ]
        , span [ class "env-key-value" ] [ text envKey ]
        ]


{-| queueRoutesId : returns reusable id for queue routes
-}
queueRoutesId : String
queueRoutesId =
    "queue-routes"


{-| repoAllowlistId : returns reusable id for repo allowlist
-}
repoAllowlistId : String
repoAllowlistId =
    "repo-allowlist"


{-| scheduleAllowlistId : returns reusable id for schedule allowlist
-}
scheduleAllowlistId : String
scheduleAllowlistId =
    "schedule-allowlist"


{-| saveButtonId : returns reusable id for save button
-}
saveButtonId : String -> String -> String
saveButtonId base id =
    base ++ "-save-" ++ id

{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Settings exposing (Model, Msg, page)

import Auth
import Components.Form
import Components.Loading
import Components.Table
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html exposing (Html, button, div, h2, p, section, span, td, text, tr)
import Html.Attributes exposing (attribute, class, disabled, scope)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultSettingsPayload)
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
    { settings : WebData Vela.Settings
    , exported : WebData String
    , cloneImage : String
    , starlarkExecLimit : Maybe Int
    , queueRoutes : ListInputForm
    , exportType : ExportType
    }


type alias ListInputForm =
    { val : String
    , editing : Dict String String
    }


type ExportType
    = Env
    | Json
    | Yaml


defaultSettingsExportType : ExportType
defaultSettingsExportType =
    Env


exportTypeToString : ExportType -> String
exportTypeToString exportType =
    case exportType of
        Env ->
            "env"

        Json ->
            "json"

        Yaml ->
            "yaml"


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { settings = RemoteData.Loading
      , exported = RemoteData.Loading
      , cloneImage = ""
      , starlarkExecLimit = Nothing
      , queueRoutes = { val = "", editing = Dict.empty }
      , exportType = defaultSettingsExportType
      }
    , Effect.batch
        [ Effect.getSettings
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetSettingsResponse
            }
        , Effect.getSettingsString
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetSettingsStringResponse
            , output = Just <| exportTypeToString defaultSettingsExportType
            }
        ]
    )



-- UPDATE


type Msg
    = -- SETTINGS
      GetSettingsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Settings ))
    | GetSettingsStringResponse (Result (Http.Detailed.Error String) ( Http.Metadata, String ))
    | UpdateSettingsResponse {} (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Settings ))
    | CloneImageOnInput String
    | CloneImageUpdate String
    | StarlarkExecLimitOnInput String
    | StarlarkExecLimitOnUpdate (Maybe Int)
    | QueueRoutesOnInput String
    | QueueRoutesAddOnClick String
    | QueueRoutesEditOnClick { id : String }
    | QueueRoutesSaveOnClick { id : String, val : String }
    | QueueRoutesEditOnInput { id : String } String
    | QueueRoutesRemoveOnClick String
    | ExportTypeOnClick ExportType


update : Shared.Model -> Route () -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetSettingsResponse response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | settings = RemoteData.Success settings
                        , cloneImage = settings.cloneImage
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

        GetSettingsStringResponse response ->
            case response of
                Ok ( meta, exported ) ->
                    ( { model
                        | exported = RemoteData.Success exported
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

        UpdateSettingsResponse _ response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | settings = RemoteData.Success settings
                      }
                    , Effect.getSettingsString
                        { baseUrl = shared.velaAPIBaseURL
                        , session = shared.session
                        , onResponse = GetSettingsStringResponse
                        , output = Just <| exportTypeToString model.exportType
                        }
                    )

                Err error ->
                    ( { model | settings = Errors.toFailure error }
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        CloneImageOnInput val ->
            ( { model
                | cloneImage = val
              }
            , Effect.none
            )

        CloneImageUpdate val ->
            let
                payload =
                    { defaultSettingsPayload
                        | cloneImage = Just val
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( model
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSettingsResponse {}
                , body = body
                }
            )

        StarlarkExecLimitOnInput val ->
            let
                limit =
                    Maybe.withDefault 5000 <| String.toInt val
            in
            ( { model
                | starlarkExecLimit = Just <| Maybe.withDefault limit <| String.toInt val
              }
            , Effect.none
            )

        StarlarkExecLimitOnUpdate val ->
            let
                payload =
                    { defaultSettingsPayload
                        | starlarkExecLimit = val
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( model
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSettingsResponse {}
                , body = body
                }
            )

        QueueRoutesOnInput val ->
            let
                queueRoutes =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes = { queueRoutes | val = val }
              }
            , Effect.none
            )

        QueueRoutesAddOnClick val ->
            let
                queueRoutes =
                    model.queueRoutes

                payload =
                    { defaultSettingsPayload
                        | queueRoutes = Just <| List.Extra.unique <| val :: RemoteData.unwrap [] .queueRoutes model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model | queueRoutes = { queueRoutes | val = "" } }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSettingsResponse {}
                , body = body
                }
            )

        QueueRoutesRemoveOnClick val ->
            let
                payload =
                    { defaultSettingsPayload
                        | queueRoutes = Just <| List.Extra.remove val <| RemoteData.unwrap [] .queueRoutes model.settings
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( model
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSettingsResponse {}
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
            , Effect.none
            )

        QueueRoutesSaveOnClick options ->
            let
                queueRoutes =
                    model.queueRoutes

                payload =
                    { defaultSettingsPayload
                        | queueRoutes =
                            model.settings
                                |> RemoteData.unwrap [] .queueRoutes
                                |> List.Extra.updateIf (\item -> item == options.id) (\_ -> options.val)
                                |> Just
                    }

                body =
                    Http.jsonBody <| Vela.encodeSettingsPayload payload
            in
            ( { model
                | queueRoutes =
                    { queueRoutes
                        | editing = Dict.remove options.id model.queueRoutes.editing
                    }
              }
            , Effect.updateSettings
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = UpdateSettingsResponse {}
                , body = body
                }
            )

        QueueRoutesEditOnInput options val ->
            let
                queueRoutes =
                    model.queueRoutes
            in
            ( { model
                | queueRoutes =
                    { queueRoutes
                        | editing = Dict.insert options.id val model.queueRoutes.editing
                    }
              }
            , Effect.none
            )

        ExportTypeOnClick val ->
            ( { model
                | exportType = val
              }
            , Effect.getSettingsString
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetSettingsStringResponse
                , output = Just <| exportTypeToString val
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route () -> Model -> View Msg
view shared route model =
    { title = "Pages.Admin.Settings"
    , body =
        [ Html.div [ class "admin-settings" ]
            [ section
                [ class "settings"

                -- , Util.testAttribute "repo-settings-events"
                ]
                [ h2 [ class "settings-title" ] [ text "Clone Image" ]
                , p [ class "settings-description" ]
                    [ text "Which image to use with the embedded clone step."
                    ]
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
                    , Html.button
                        [ Html.Attributes.classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| CloneImageUpdate model.cloneImage
                        ]
                        [ text "update" ]
                    ]
                ]
            , section
                [ class "settings"

                -- , Util.testAttribute "repo-settings-events"
                ]
                [ h2 [ class "settings-title" ] [ text "Starlark" ]
                , p [ class "settings-description" ]
                    [ text "Exec limit provided to Starlark compiler."
                    ]
                , div [ class "form-controls" ]
                    [ Components.Form.viewNumberInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "starlark-exec-limit"
                        , val = model.starlarkExecLimit
                        , placeholder_ = "5000"
                        , classList_ = []
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = StarlarkExecLimitOnInput
                        , disabled_ = False
                        , min = 1
                        , max = 10000
                        }
                    , Html.button
                        [ Html.Attributes.classList
                            [ ( "button", True )
                            , ( "-outline", True )
                            ]
                        , onClick <| StarlarkExecLimitOnUpdate model.starlarkExecLimit
                        ]
                        [ text "update" ]
                    ]
                ]
            , section
                [ class "settings"
                ]
                [ h2 [ class "settings-title" ] [ text "Queue Routes" ]
                , p [ class "settings-description" ]
                    [ text "The queue routes used when queuing builds."
                    ]
                , viewQueueRoutesTable shared model
                ]
            , section [ class "settings", Util.testAttribute "admin-settings-export-type" ]
                [ h2 [ class "settings-title" ] [ text "Import/Export" ]
                , p [ class "settings-description" ]
                    [ text "Update or export platform settings via file."
                    ]
                , div [ class "admin-settings-export-container" ]
                    [ div [ class "form-controls", class "-stack" ]
                        [ Components.Form.viewRadio
                            { value = exportTypeToString model.exportType
                            , field = exportTypeToString Env
                            , title = ".env"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick Env
                            , disabled_ = False
                            , id_ = "type-" ++ exportTypeToString Env
                            }
                        , Components.Form.viewRadio
                            { value = exportTypeToString model.exportType
                            , field = exportTypeToString Json
                            , title = "JSON"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick Json
                            , disabled_ = False
                            , id_ = "type-" ++ exportTypeToString Json
                            }
                        , Components.Form.viewRadio
                            { value = exportTypeToString model.exportType
                            , field = exportTypeToString Yaml
                            , title = "YAML"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick Yaml
                            , disabled_ = False
                            , id_ = "type-" ++ exportTypeToString Yaml
                            }
                        ]
                    ]
                , div [ class "admin-settings-export-textarea-container" ]
                    [ Components.Form.viewTextarea
                        { id_ = "settings-export"
                        , val = RemoteData.withDefault "" model.exported
                        , placeholder_ = ""
                        , classList_ = [ ( "admin-settings-export-textarea", True ) ]
                        , rows_ = Nothing
                        , wrap_ = Nothing
                        , msg = CloneImageOnInput
                        , disabled_ = False
                        }
                    , Components.Form.viewCopyButton
                        { id_ = "copy settings"
                        , msg = CloneImageOnInput
                        , text_ = "Copy Settings"
                        , classList_ = []
                        , disabled_ = False
                        , content = RemoteData.withDefault "" model.exported
                        }
                    ]
                ]
            , section
                [ class "settings"

                -- , Util.testAttribute "repo-settings-events"
                ]
                [ h2 [ class "settings-title" ] [ text "Table" ]
                , p [ class "settings-description" ]
                    [ text "View all platform settings."
                    ]
                , viewSettingsTable shared model
                ]
            ]
        ]
    }



-- SETTINGS TABLE


{-| viewSettingsTable : renders a settings record as a table
-}
viewSettingsTable : Shared.Model -> Model -> Html Msg
viewSettingsTable shared model =
    let
        actions =
            Nothing

        ( noRowsView, rows ) =
            let
                viewHttpError e =
                    span [ Util.testAttribute "settings-error" ]
                        [ text <|
                            case e of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No settings found"

                                        _ ->
                                            "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No settings found"
                        ]
            in
            case model.settings of
                RemoteData.Success s ->
                    ( text "No settings found"
                    , settingsToRows shared s
                    )

                RemoteData.Failure error ->
                    ( viewHttpError error, [] )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                Nothing
                "settings"
                noRowsView
                settingsTableHeaders
                rows
                actions
    in
    div []
        [ Components.Table.view cfg
        ]


{-| settingsToRows : takes settings object and produces list of Table rows
-}
settingsToRows : Shared.Model -> Vela.Settings -> Components.Table.Rows String Msg
settingsToRows shared settings =
    [ Components.Table.Row "clone_image"
        (viewSettingsRow shared
            "VELA_CLONE_IMAGE"
            (Components.Table.viewListItemCell
                { dataLabel = "settings-table-field-clone-image"
                , parentClassList = []
                , itemWrapperClassList = []
                , itemClassList = []
                , children =
                    [ text settings.cloneImage
                    ]
                }
            )
        )
    , Components.Table.Row "starlark_exec_limit"
        (viewSettingsRow shared
            "VELA_COMPILER_EXEC_STARLARK_LIMIT"
            (Components.Table.viewItemCell
                { dataLabel = "settings-table-field-starlark-limit"
                , parentClassList = []
                , itemClassList = []
                , children =
                    [ text <| String.fromInt settings.starlarkExecLimit
                    ]
                }
            )
        )
    , Components.Table.Row "queue_routes"
        (viewSettingsRow shared
            "VELA_QUEUE_ROUTES"
            (td
                [ attribute "data-label" "events"
                , scope "row"
                , class "break-word"
                ]
                [ Components.Table.viewListCell
                    { dataLabel = "routes"
                    , items = settings.queueRoutes
                    , none = "no queue routes"
                    , itemWrapperClassList = []
                    }
                ]
            )
        )
    ]


{-| settingsTableHeaders : returns table headers for settings table
-}
settingsTableHeaders : Components.Table.Columns
settingsTableHeaders =
    [ ( Nothing, "Field" )
    , ( Nothing, "Env Key" )
    , ( Nothing, "Value" )
    ]


{-| viewSettingsRow : takes item and renders a table row
-}
viewSettingsRow : Shared.Model -> String -> Html Msg -> String -> Html Msg
viewSettingsRow shared envKey viewValue field =
    tr [ Util.testAttribute <| "item-row" ]
        [ Components.Table.viewItemCell
            { dataLabel = "item"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ text field
                ]
            }
        , Components.Table.viewListItemCell
            { dataLabel = "settings-table-field-clone-image"
            , parentClassList = []
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ text envKey
                ]
            }
        , viewValue
        ]



-- queue routeS


{-| viewQueueRoutesTable : renders a list of queue routes
-}
viewQueueRoutesTable : Shared.Model -> Model -> Html Msg
viewQueueRoutesTable shared model =
    let
        actions =
            Nothing

        ( noRowsView, rows ) =
            let
                viewHttpError e =
                    span [ Util.testAttribute "queue-routes-error" ]
                        [ text <|
                            case e of
                                Http.BadStatus statusCode ->
                                    case statusCode of
                                        401 ->
                                            "No settings found"

                                        _ ->
                                            "No settings found, there was an error with the server (" ++ String.fromInt statusCode ++ ")"

                                _ ->
                                    "No settings found"
                        ]
            in
            case model.settings of
                RemoteData.Success s ->
                    ( text "No queue routes found"
                    , queueRoutesToRows shared model s.queueRoutes
                    )

                RemoteData.Failure error ->
                    ( viewHttpError error, [] )

                _ ->
                    ( Components.Loading.viewSmallLoader, [] )

        cfg =
            Components.Table.Config
                Nothing
                "routes"
                noRowsView
                []
                rows
                actions
    in
    div []
        [ div [ class "form-controls" ]
            [ Components.Form.viewInput
                { title = Nothing
                , subtitle = Nothing
                , id_ = "queue-route"
                , val = model.queueRoutes.val
                , placeholder_ = "vela"
                , classList_ = []
                , wrapperClassList =
                    [ ( "-wide", True )
                    ]
                , rows_ = Nothing
                , wrap_ = Nothing
                , msg = QueueRoutesOnInput
                , disabled_ = False
                }
            , Html.button
                [ Html.Attributes.classList
                    [ ( "button", True )
                    , ( "-outline", True )
                    ]
                , onClick <| QueueRoutesAddOnClick model.queueRoutes.val
                , disabled <| (String.length model.queueRoutes.val == 0) || (not <| RemoteData.isSuccess model.settings)
                ]
                [ text "add" ]
            ]
        , Components.Table.view cfg
        ]


{-| queueRoutesToRows : takes list of queue routes and produces list of Table rows
-}
queueRoutesToRows : Shared.Model -> Model -> List String -> Components.Table.Rows String Msg
queueRoutesToRows shared model items =
    List.map (\item -> Components.Table.Row item (viewqueueRouteRow shared model)) items


{-| queueRoutesTableHeaders : returns table headers for queue routes table
-}
queueRoutesTableHeaders : Components.Table.Columns
queueRoutesTableHeaders =
    [ ( Nothing, "Route" )
    , ( Just "table-icon", "Remove" )
    ]


{-| viewqueueRouteRow : takes item and renders a table row
-}
viewqueueRouteRow : Shared.Model -> Model -> String -> Html Msg
viewqueueRouteRow shared model item =
    let
        editing =
            Maybe.Extra.unwrap Nothing (\e -> Just e) <| Dict.get item model.queueRoutes.editing
    in
    tr [ Util.testAttribute <| "item-row" ]
        [ Components.Table.viewItemCell
            { dataLabel = "item"
            , parentClassList = []
            , itemClassList = []
            , children =
                [ case editing of
                    Just val ->
                        Components.Form.viewInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "queue-route"
                            , val = val
                            , placeholder_ = "vela"
                            , wrapperClassList = []
                            , classList_ = []
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = QueueRoutesEditOnInput { id = item }
                            , disabled_ = False
                            }

                    Nothing ->
                        text item
                ]
            }
        , Components.Table.viewIconCell
            { dataLabel = "copy yaml"
            , parentClassList = []
            , itemWrapperClassList = []
            , itemClassList = []
            , children =
                [ div []
                    [ case editing of
                        Just val ->
                            button
                                [ class "remove-button"
                                , attribute "aria-label" "remove queue route "
                                , class "button"
                                , class "-icon"
                                , onClick <| QueueRoutesSaveOnClick { id = item, val = val }
                                , Util.testAttribute "remove-route"
                                ]
                                [ FeatherIcons.save
                                    |> FeatherIcons.withSize 18
                                    |> FeatherIcons.toHtml []
                                ]

                        _ ->
                            button
                                [ class "remove-button"
                                , attribute "aria-label" "remove queue route "
                                , class "button"
                                , class "-icon"
                                , onClick <| QueueRoutesEditOnClick { id = item }
                                , Util.testAttribute "remove-route"
                                ]
                                [ FeatherIcons.edit2
                                    |> FeatherIcons.withSize 18
                                    |> FeatherIcons.toHtml []
                                ]
                    , button
                        [ class "remove-button"
                        , attribute "aria-label" "remove queue route "
                        , class "button"
                        , class "-icon"
                        , onClick <| QueueRoutesRemoveOnClick item
                        , Util.testAttribute "remove-route"
                        ]
                        [ FeatherIcons.minusSquare
                            |> FeatherIcons.withSize 18
                            |> FeatherIcons.toHtml []
                        ]
                    ]
                ]
            }
        ]

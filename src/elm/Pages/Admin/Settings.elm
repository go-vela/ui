{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Settings exposing (Model, Msg, page)

import Auth
import Components.Form
import Effect exposing (Effect)
import Html exposing (div, h2, p, section, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
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
        , view = view shared
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
              , content = "vela view workers"
              , docs = Just "cli/worker/get"
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
    , exportType : String
    }


defaultSettingsOutputType : String
defaultSettingsOutputType =
    "env"


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { settings = RemoteData.Loading
      , exported = RemoteData.Loading
      , cloneImage = ""
      , exportType = defaultSettingsOutputType
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
            , output = Just defaultSettingsOutputType
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
    | ExportTypeOnClick String


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
                        , output = Just model.exportType
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

        ExportTypeOnClick val ->
            ( { model
                | exportType = val
              }
            , Effect.getSettingsString
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetSettingsStringResponse
                , output = Just val
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    { title = "Pages.Admin.Settings"
    , body =
        [ Html.div [ class "admin-settings" ]
            [ section
                [ class "settings"

                -- , Util.testAttribute "repo-settings-events"
                ]
                [ h2 [ class "settings-title" ] [ text "Clone Image" ]
                , p [ class "settings-description" ]
                    [ text "Control which image to use with the embedded clone step."
                    ]
                , div [ class "form-controls" ]
                    [ Components.Form.viewInput
                        { title = Nothing
                        , subtitle = Nothing
                        , id_ = "clone-image"
                        , val = model.cloneImage
                        , placeholder_ = "docker.io/target/vela-git:latest"
                        , classList_ = []
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
            , section [ class "settings", Util.testAttribute "admin-settings-export-type" ]
                [ h2 [ class "settings-title" ] [ text "Export" ]
                , p [ class "settings-description" ]
                    [ text "Convert platform settings into a reusable format."
                    ]
                , div [ class "admin-settings-export-container" ]
                    [ div [ class "form-controls", class "-stack" ]
                        [ Components.Form.viewRadio
                            { value = model.exportType
                            , field = "env"
                            , title = ".env"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick "env"
                            , disabled_ = False
                            , id_ = "type-env"
                            }
                        , Components.Form.viewRadio
                            { value = model.exportType
                            , field = "json"
                            , title = "JSON"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick "json"
                            , disabled_ = False
                            , id_ = "type-json"
                            }
                        , Components.Form.viewRadio
                            { value = model.exportType
                            , field = "yaml"
                            , title = "YAML"
                            , subtitle = Nothing
                            , msg = ExportTypeOnClick "yaml"
                            , disabled_ = False
                            , id_ = "type-yaml"
                            }
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
                            { id_ = "delete"
                            , msg = CloneImageOnInput
                            , text_ = "Copy Settings"
                            , classList_ = []
                            , disabled_ = False
                            , content = RemoteData.withDefault "" model.exported
                            }
                        ]
                    ]
                ]
            ]
        ]
    }

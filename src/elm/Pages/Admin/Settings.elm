{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Admin.Settings exposing (Model, Msg, page)

import Auth
import Components.Form
import Effect exposing (Effect)
import Html
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Vela exposing (defaultSettingsPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default_Admin
        { navButtons = []
        , utilButtons = []
        , helpCommands =
            [ { name = "List Workers"
              , content = "vela get workers"
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
    , cloneImage : String
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { settings = RemoteData.Loading
      , cloneImage = ""
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
      GetSettingsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Settings ))
    | CloneImageOnInput String
    | CloneImageUpdate String
    | UpdateSettingsResponse {} (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Settings ))


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

        UpdateSettingsResponse _ response ->
            case response of
                Ok ( meta, settings ) ->
                    ( { model
                        | settings = RemoteData.Success settings
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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Pages.Admin.Settings"
    , body =
        [ Html.div []
            [ Components.Form.viewInput
                { title = Just "Clone Image"
                , subtitle = Nothing
                , id_ = "clone-image"
                , val = model.cloneImage
                , placeholder_ = "docker.io/target/vela-git:latest"
                , classList_ = [ ( "clone-image", True ) ]
                , rows_ = Nothing
                , wrap_ = Nothing
                , msg = CloneImageOnInput
                , disabled_ = False
                }
            , Components.Form.viewButton
                { id_ = "submit-clone-image"
                , msg = CloneImageUpdate model.cloneImage
                , text_ = "Submit"
                , classList_ = []
                , disabled_ = False
                }
            ]
        ]
    }

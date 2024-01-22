{--
SPDX-License-Identifier: Apache-2.0
--}


module Layouts.Default.Build exposing (Model, Msg, Props, layout, map)

import Components.Build
import Components.RecentBuilds
import Components.Tabs
import Effect exposing (Effect)
import Html exposing (..)
import Http
import Http.Detailed
import Layout exposing (Layout)
import Layouts.Default
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors as Errors
import Vela
import View exposing (View)


type alias Props contentMsg =
    { org : String
    , repo : String
    , buildNumber : String
    , build : WebData Vela.Build
    , toBuildPath : String -> Route.Path.Path
    , navButtons : List (Html contentMsg)
    , utilButtons : List (Html contentMsg)
    }


map : (msg1 -> msg2) -> Props msg1 -> Props msg2
map fn props =
    { org = props.org
    , repo = props.repo
    , buildNumber = props.buildNumber
    , build = props.build
    , toBuildPath = props.toBuildPath
    , navButtons = List.map (Html.map fn) props.navButtons
    , utilButtons = List.map (Html.map fn) props.utilButtons
    }


layout : Props contentMsg -> Shared.Model -> Route () -> Layout (Layouts.Default.Props contentMsg) Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init props shared
        , update = update shared
        , view = view props shared route
        , subscriptions = subscriptions
        }
        |> Layout.withParentProps
            { navButtons = []
            , utilButtons = []
            }



-- MODEL


type alias Model =
    { builds : WebData (List Vela.Build)
    }


init : Props contentMsg -> Shared.Model -> () -> ( Model, Effect Msg )
init props shared _ =
    ( { builds = RemoteData.Loading
      }
    , Effect.getRepoBuilds
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetBuildsResponse
        , pageNumber = Nothing
        , perPage = Nothing
        , maybeEvent = Nothing
        , org = props.org
        , repo = props.repo
        }
    )



-- UPDATE


type Msg
    = GetBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg model =
    case msg of
        GetBuildsResponse response ->
            case response of
                Ok ( _, builds ) ->
                    ( { model
                        | builds = RemoteData.Success builds
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | builds = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Props contentMsg -> Shared.Model -> Route () -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model } -> View contentMsg
view props shared route { toContentMsg, model, content } =
    { title = props.org ++ "/" ++ props.repo ++ " #" ++ props.buildNumber
    , body =
        [ Components.RecentBuilds.view shared
            { builds = model.builds
            , build = props.build
            , num = 10
            , toPath = props.toBuildPath
            }
        , Components.Build.view shared
            { build = props.build
            , showFullTimestamps = False
            , actionsMenu = Nothing
            }
        , Components.Tabs.viewBuildTabs shared
            { org = props.org
            , repo = props.repo
            , buildNumber = props.buildNumber
            , currentPath = route.path
            }
        ]
            ++ content.body
    }

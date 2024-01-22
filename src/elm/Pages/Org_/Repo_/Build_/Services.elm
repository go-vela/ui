{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Build_.Services exposing (..)

import Api.Pagination
import Auth
import Components.Pager
import Components.Svgs as SvgBuilder
import Components.Table
import Dict
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        , rows
        , scope
        )
import Http
import Http.Detailed
import Layouts
import LinkHeader exposing (WebLink)
import List
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Svg.Attributes
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String, buildNumber : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Build
        { org = route.params.org
        , repo = route.params.repo
        , buildNumber = route.params.buildNumber
        , build = model.build
        , toBuildPath =
            \buildNumber ->
                Route.Path.Org_Repo_Build_
                    { org = route.params.org
                    , repo = route.params.repo
                    , buildNumber = buildNumber
                    }
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { build : WebData Vela.Build
    }


init : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { build = RemoteData.Loading
      }
    , Effect.batch
        [ Effect.getBuild
            { baseUrl = shared.velaAPI
            , session = shared.session
            , onResponse = GetBuildResponse
            , org = route.params.org
            , repo = route.params.repo
            , buildNumber = route.params.buildNumber
            }
        ]
    )



-- UPDATE


type Msg
    = GetBuildResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Build ))


update : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        GetBuildResponse response ->
            case response of
                Ok ( _, build ) ->
                    ( { model
                        | build = RemoteData.Success build
                      }
                    , Effect.none
                    )

                Err error ->
                    ( { model | build = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String, buildNumber : String } -> Model -> View Msg
view shared route model =
    { title = "#" ++ route.params.buildNumber
    , body =
        [ text <| "services+logs here"
        ]
    }

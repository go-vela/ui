{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_ exposing (Model, Msg, page, view)

import Auth
import Components.Repos
import Effect exposing (Effect)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Errors as Errors
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default_Org
        { org = route.params.org
        , navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    { repos : WebData (List Vela.Repository)
    }


init : Shared.Model -> Route { org : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repos = RemoteData.Loading
      }
    , Effect.getOrgRepos
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetOrgReposResponse
        , org = route.params.org
        }
    )



-- UPDATE


type Msg
    = GetOrgReposResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Repository ))


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GetOrgReposResponse response ->
            case response of
                Ok ( _, repos ) ->
                    ( { model | repos = RemoteData.Success repos }
                    , Effect.none
                    )

                Err error ->
                    ( { model | repos = Errors.toFailure error }
                    , Effect.handleHttpError { httpError = error }
                    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String } -> Model -> View Msg
view shared route model =
    let
        body =
            Components.Repos.view shared
                { repos = model.repos
                }
    in
    { title = route.params.org
    , body =
        [ body
        ]
    }

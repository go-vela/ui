{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_Repos exposing (Model, Msg, page, view)

import Auth
import Components.Repos
import Effect exposing (Effect)
import Html
import Http
import Http.Detailed
import Layouts
import List
import Maybe.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Shared
import Utils.Helpers as Util
import Vela exposing (BuildNumber, Org, Repo)
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
        , nil = []
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
                    -- todo: handle GET builds errors
                    ( model
                    , Effect.none
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

{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.PageTemplate_ exposing (Model, Msg, page, view)

import Auth
import Components.Favorites as Favorites
import Components.Search
    exposing
        ( homeSearchBar
        , toLowerContains
        )
import Components.Svgs as SvgBuilder
import Dict exposing (Dict)
import Effect exposing (Effect)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , h1
        , p
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import Layouts
import List
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..))
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Helpers as Util
import Vela exposing (Favorites, Org, Repo)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }
        |> Page.withLayout (toLayout user)



-- LAYOUT


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user model =
    Layouts.Default
        { navButtons = []
        , utilButtons = []
        }



-- INIT


type alias Model =
    {}


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared model =
    let
        body =
            text "we are on the OrgRepoPage"
    in
    { title = "Pages.OrgRepoPage"
    , body =
        [ body
        ]
    }

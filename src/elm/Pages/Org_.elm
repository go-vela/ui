{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_ exposing (Model, Msg, page, view)

import Auth
import Effect exposing (Effect)
import Html exposing (Html, a, div, h1, p, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Shared
import Utils.Errors as Errors
import Utils.Helpers as Util
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
    { title = route.params.org
    , body =
        [ viewOrgRepos shared route model
        ]
    }


viewOrgRepos : Shared.Model -> Route { org : String } -> Model -> Html Msg
viewOrgRepos shared route model =
    case model.repos of
        Success repos ->
            if List.length repos == 0 then
                div []
                    [ h1 [] [ text "No Repositories are enabled for this Organization!" ]
                    , p [] [ text "Enable repositories" ]
                    , a
                        [ class "button"
                        , class "-outline"
                        , Util.testAttribute "source-repos"
                        , Route.Path.href Route.Path.AccountSourceRepos
                        ]
                        [ text "Source Repositories" ]
                    ]

            else
                div [] (List.map viewRepo repos)

        Loading ->
            Util.largeLoader

        NotAsked ->
            Util.largeLoader

        Failure _ ->
            div [ Util.testAttribute "repos-error" ]
                [ p []
                    [ text "There was an error fetching repos, please refresh or try again later!"
                    ]
                ]


{-| viewRepo : renders row of repos with action buttons
-}
viewRepo : Vela.Repository -> Html Msg
viewRepo repo =
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text repo.name ]
        , div [ class "buttons" ]
            [ a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-settings"
                , Route.Path.href <| Route.Path.Org_Repo_Settings { org = repo.org, repo = repo.name }
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-audit"
                , Route.Path.href <| Route.Path.Org_Repo_Audit { org = repo.org, repo = repo.name }
                ]
                [ text "Audit" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Route.Path.href <| Route.Path.Org_Repo_Secrets { org = repo.org, repo = repo.name }
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Route.Path.href <| Route.Path.Org_Repo_ { org = repo.org, repo = repo.name }
                ]
                [ text "View" ]
            ]
        ]

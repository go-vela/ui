{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_ exposing (Model, Msg, page, view)

import Auth
import Components.Builds
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
        , br
        , code
        , details
        , div
        , em
        , h1
        , li
        , ol
        , p
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , href
        )
import Http
import Http.Detailed
import Layouts
import List
import List.Extra
import Page exposing (Page)
import Pages.Build.Model exposing (Msgs)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Route.Path
import Routes
import Shared
import Time exposing (Posix, Zone)
import Utils.Errors as Errors exposing (viewResourceError)
import Utils.Helpers as Util exposing (largeLoader)
import Vela exposing (BuildNumber, BuildsModel, Event, Favorites, Org, Repo)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update
        , subscriptions = subscriptions
        , view = view shared route
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
    { builds : WebData Vela.Builds
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { builds = RemoteData.Loading
      }
    , Effect.getOrgRepoBuilds
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetOrgRepoBuildsResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetOrgRepoBuildsResponse (Result (Http.Detailed.Error String) ( Http.Metadata, List Vela.Build ))
    | ApproveBuild Org Repo BuildNumber
    | RestartBuild Org Repo BuildNumber
    | CancelBuild Org Repo BuildNumber
    | ToggleActionsMenu (Maybe Int) (Maybe Bool)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        GetOrgRepoBuildsResponse response ->
            case response of
                Ok ( _, builds ) ->
                    ( { model | builds = RemoteData.Success builds }
                    , Effect.none
                    )

                Err error ->
                    -- todo: handle GET builds errors
                    ( model
                    , Effect.none
                    )

        ApproveBuild _ _ _ ->
            ( model, Effect.none )

        RestartBuild _ _ _ ->
            ( model, Effect.none )

        CancelBuild _ _ _ ->
            ( model, Effect.none )

        ToggleActionsMenu _ _ ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        body =
            viewBuilds shared route model
    in
    { title = "Pages.OrgRepoPage"
    , body =
        [ body
        ]
    }



-- viewBuilds : BuildsModel -> Msgs msgs -> List Int -> Posix -> Zone -> Org -> Repo -> Maybe Event -> Html msgs
-- viewBuilds buildsModel msgs buildMenuOpen now zone org repo maybeEvent =


viewBuilds : Shared.Model -> Route { org : String, repo : String } -> Model -> Html Msg
viewBuilds shared route model =
    -- text "viewBuilds from the NEW WORLD"
    let
        msgs =
            { approveBuild = ApproveBuild
            , restartBuild = RestartBuild
            , cancelBuild = CancelBuild
            , toggleActionsMenu = ToggleActionsMenu
            }

        settingsLink : String
        settingsLink =
            "/" ++ String.join "/" [ route.params.org, route.params.repo ] ++ "/settings"

        -- todo: handle query parameters ?event=push etc
        maybeEvent =
            Nothing

        showFullTimestamps =
            False

        none : Html msg
        none =
            case maybeEvent of
                Nothing ->
                    div []
                        [ h1 [] [ text "Your repository has been enabled!" ]
                        , p [] [ text "Builds will show up here once you have:" ]
                        , ol [ class "list" ]
                            [ li []
                                [ text "A "
                                , code [] [ text ".vela.yml" ]
                                , text " file that describes your build pipeline in the root of your repository."
                                , br [] []
                                , a [ href "https://go-vela.github.io/docs/usage/" ] [ text "Review the documentation" ]
                                , text " for help or "
                                , a [ href "https://go-vela.github.io/docs/usage/examples/" ] [ text "check some of the pipeline examples" ]
                                , text "."
                                ]
                            , li []
                                [ text "Trigger one of the "
                                , a [ href settingsLink ] [ text "configured webhook events" ]
                                , text " by performing the respective action via "
                                , em [] [ text "Git" ]
                                , text "."
                                ]
                            ]
                        , p [] [ text "Happy building!" ]
                        ]

                Just event ->
                    div []
                        [ h1 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
    in
    case model.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <|
                    List.map
                        (Components.Builds.viewPreview msgs shared.buildMenuOpen True shared.time shared.zone route.params.org route.params.repo showFullTimestamps)
                        builds

        RemoteData.Loading ->
            largeLoader

        RemoteData.NotAsked ->
            largeLoader

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "builds for this repository", testLabel = "builds" }

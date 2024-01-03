module Pages.Home_ exposing (Model, Msg, page, view)

import Dict exposing (Dict)
import Effect exposing (Effect)
import Favorites exposing (ToggleFavorite, starToggle)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , details
        , div
        , h1
        , input
        , p
        , span
        , summary
        , text
        )
import Html.Attributes
    exposing
        ( attribute
        , autofocus
        , class
        , disabled
        , id
        , placeholder
        , value
        )
import Html.Events exposing (onInput)
import List
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Routes
import Search
    exposing
        ( SimpleSearch
        , homeSearchBar
        , toLowerContains
        )
import Shared
import Shared.Msg
import SvgBuilder
import Util
import Vela exposing (CurrentUser, Favorites)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }



-- INIT


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
    | SomeHomeMsg
    | SomeSharedMsg
    | ToggleFavorite
    | SearchFavorites String


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        SomeHomeMsg ->
            ( model
            , Effect.none
            )

        SomeSharedMsg ->
            ( model
            , Effect.someSharedMsg
            )

        ToggleFavorite ->
            ( model
            , Effect.none
            )

        SearchFavorites _ ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        blankMessage : Html msg
        blankMessage =
            div [ class "overview" ]
                [ h1 [] [ text "Let's get Started!" ]
                , p [] [ text "To have Vela start building your projects we need to get them enabled." ]
                , p []
                    [ text "To display a repository here, click the "
                    , SvgBuilder.star False
                    ]
                , p [] [ text "Enable repositories from your GitHub account on Vela now!" ]
                , a [ class "button", Routes.href Routes.SourceRepositories ] [ text "Source Repositories" ]
                ]

        body =
            div [ Util.testAttribute "overview" ] <|
                case shared.user of
                    Success u ->
                        if List.length u.favorites > 0 then
                            [ homeSearchBar shared.favoritesFilter
                            , viewFavorites u.favorites shared.favoritesFilter
                            ]

                        else
                            [ blankMessage ]

                    Loading ->
                        [ h1 [] [ text "Loading your Repositories", span [ class "loading-ellipsis" ] [] ] ]

                    NotAsked ->
                        [ text "" ]

                    Failure _ ->
                        [ text "" ]
    in
    { title = "Pages.Home_New_"
    , body =
        [ body
        ]
    }


{-| viewFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFavorites : Favorites -> String -> Html msg
viewFavorites favorites filter =
    -- no search input
    if String.isEmpty filter then
        favorites
            |> toOrgFavorites
            |> viewFavoritesByOrg

    else
        viewFilteredFavorites favorites filter


{-| viewFilteredFavorites : takes favorites, user search input and favorite action and renders favorites
-}
viewFilteredFavorites : Favorites -> String -> Html msg
viewFilteredFavorites favorites filter =
    let
        filteredRepos =
            favorites
                |> List.filter (\repo -> toLowerContains filter repo)
    in
    div [ class "filtered-repos" ] <|
        -- Render the found repositories
        if not <| List.isEmpty filteredRepos then
            filteredRepos
                |> List.map (viewFavorite favorites True)

        else
            -- No repos matched the search
            [ div [ class "no-results" ] [ text "No results" ] ]


{-| viewFavoritesByOrg : takes favorites dictionary and favorite action and renders favorites by org
-}
viewFavoritesByOrg : Dict String Favorites -> Html msg
viewFavoritesByOrg orgFavorites =
    orgFavorites
        |> Dict.toList
        |> Util.filterEmptyLists
        |> List.map (\( org, favs ) -> viewOrg org favs)
        |> div [ class "repo-list" ]


{-| toOrgFavorites : takes favorites and organizes them by org in a dict
-}
toOrgFavorites : Favorites -> Dict String Favorites
toOrgFavorites favorites =
    List.foldr
        (\x acc ->
            Dict.update
                (Maybe.withDefault "" <|
                    List.head <|
                        String.split "/" x
                )
                (Maybe.map ((::) x) >> Maybe.withDefault [ x ] >> Just)
                acc
        )
        Dict.empty
    <|
        List.sort favorites


{-| viewOrg : takes org, favorites and favorite action and renders favorites by org
-}
viewOrg : String -> Favorites -> Html msg
viewOrg org favorites =
    details [ class "details", class "-with-border", attribute "open" "open", Util.testAttribute "repo-org" ]
        (summary [ class "summary" ]
            [ a [ Routes.href <| Routes.OrgRepositories org Nothing Nothing ] [ text org ]
            , FeatherIcons.chevronDown |> FeatherIcons.withSize 20 |> FeatherIcons.withClass "details-icon-expand" |> FeatherIcons.toHtml []
            ]
            :: List.map (viewFavorite favorites False) favorites
        )


{-| viewFavorite : takes favorites and favorite action and renders single favorite
-}
viewFavorite : Favorites -> Bool -> String -> Html msg
viewFavorite favorites filtered favorite =
    let
        ( org, repo ) =
            ( Maybe.withDefault "" <| List.Extra.getAt 0 <| String.split "/" favorite
            , Maybe.withDefault "" <| List.Extra.getAt 1 <| String.split "/" favorite
            )

        name =
            if filtered then
                favorite

            else
                repo
    in
    div [ class "item", Util.testAttribute "repo-item" ]
        [ div [] [ text name ]
        , div [ class "buttons" ]
            -- [ starToggle org repo toggleFavorite <| List.member favorite favorites
            [ a
                [ class "button"
                , class "-outline"
                , Routes.href <| Routes.RepoSettings org repo
                ]
                [ text "Settings" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-hooks"
                , Routes.href <| Routes.Hooks org repo Nothing Nothing
                ]
                [ text "Hooks" ]
            , a
                [ class "button"
                , class "-outline"
                , Util.testAttribute "repo-secrets"
                , Routes.href <| Routes.RepoSecrets "native" org repo Nothing Nothing
                ]
                [ text "Secrets" ]
            , a
                [ class "button"
                , Util.testAttribute "repo-view"
                , Routes.href <| Routes.RepositoryBuilds org repo Nothing Nothing Nothing
                ]
                [ text "View" ]
            ]
        ]



-- todo: this will eventually move to an elm-land component


homeSearchBar : String -> Html Msg
homeSearchBar filter =
    div [ class "form-control", class "-with-icon", class "-is-expanded", Util.testAttribute "home-search-bar" ]
        [ input
            [ Util.testAttribute "home-search-input"
            , autofocus True
            , placeholder "Type to filter all favorites..."
            , value <| filter
            , onInput SearchFavorites
            ]
            []
        , FeatherIcons.filter |> FeatherIcons.toHtml [ attribute "aria-label" "filter" ]
        ]

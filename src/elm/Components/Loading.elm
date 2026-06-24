module Components.Loading exposing (viewLargeLoader, viewSmallLoader, viewSmallLoaderWithText)

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


{-| viewSmallLoader : renders a small loading spinner for better transitioning UX.
-}
viewSmallLoader : Html msg
viewSmallLoader =
    div [ class "small-loader" ] [ div [ class "loader-spinner" ] [], div [ class "loader-label" ] [] ]


{-| viewSmallLoaderWithText : renders a small loading spinner for better transitioning UX with additional loading text.
-}
viewSmallLoaderWithText : String -> Html msg
viewSmallLoaderWithText label =
    div [ class "small-loader" ] [ div [ class "loader-spinner" ] [], div [ class "loader-label" ] [ text label ] ]


{-| viewLargeLoader : renders a large loading spinner for better transitioning UX.
-}
viewLargeLoader : Html msg
viewLargeLoader =
    div [ class "large-loader" ] [ div [ class "loader-spinner" ] [], div [ class "loader-label" ] [] ]

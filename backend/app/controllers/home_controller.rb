class HomeController < ApplicationController
  def index
    render html: <<~HTML.html_safe
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Messy</title>
        <style>
          body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background-color: hsl(184, 50%, 26%);
          }
          img {
            height: 48px;
            width: auto;
          }
        </style>
      </head>
      <body>
        <img src="/nameLogo.png" alt="Messy" />
      </body>
      </html>
    HTML
  end
end

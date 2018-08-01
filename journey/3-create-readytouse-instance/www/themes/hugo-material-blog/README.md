# Hugo Material Blog

Clean Material Design blog theme for Hugo.

## Demo

You can find a demo [here](https://themes.gohugo.io/theme/hugo-material-blog/).

## Screenshots

![preview](https://raw.githubusercontent.com/Xzya/hugo-material-blog/master/images/screenshot.png)
![preview](https://raw.githubusercontent.com/Xzya/hugo-material-blog/master/images/screenshot2.png)

## Configuration

Check `exampleSite/config.toml` for an example configuration.

## Cover image

You can use the `cover_image` param in the frontmatter of a post to include a cover image:

`cover_image: "images/image1.jpeg"`

## Brand

The brand can be overriden by adding your own layout `layouts/partials/brand.html`. Check `exampleSite/layouts/partials/brand.html` for an example.

## Footer content

The footer content can be overriden by adding your own layout in `layouts/partials/footer-content.html`. Check `exampleSite/layouts/partials/footer-content.html` for an example.

## Menu

The navbar displays the `main` menus by default. You can find more details about how to configure it [here](https://gohugo.io/templates/menu-templates/), as well as in the `exampleSite/config.toml`.

## Footer menu

You can include menus in the footer by setting them in the `footer_menus` array:

```toml
[params]
  [[params.footer_menus]]
    name = "Services"
    menu = "services"
  [[params.footer_menus]]
    name = "Links"
    menu = "other"
```

This also supports localization:

```toml
[languages.en]
  languageName = "English"
  [[languages.en.params.footer_menus]]
    name = "Services"
    menu = "footer1"
  [[languages.en.params.footer_menus]]
    name = "Other"
    menu = "footer2"

[languages.fr]
  languageName = "Français"
  [[languages.fr.params.footer_menus]]
    name = "Services"
    menu = "footer1"
  [[languages.fr.params.footer_menus]]
    name = "Autre"
    menu = "footer2"
```

Check `exampleSite/config.toml` for more examples.

## Additional content in `<head>`

You can add your own content in the `<head>` by overriding `partials/head-custom.html`.

## License

Open sourced under the [MIT license](./LICENSE.md).
## Where are the generated files?

There are 3 places you might see files getting generated. On _every_ build files
might go to _cache_ (`.dart_tool/build/generated/*`), and _source_ (the working
tree of your package). These are determined by the `build_to` configuration of
the Builders you are using. When a Builder specifies `build_to: source` you will
see them next to your other files but should not edit them by hand, and they are
generally meant to be published with your package. If you see a warning about
"conflicting outputs" they refer to _source_ outputs, because when the build
tool is starting with no prior information it can't tell if it might be
overwriting some file you wrote by hand.

Separately the `--output` option can specify a directory to create a _merged_
view of all the files in the build system. This copies _hand written source_
files, along with _source_ and _cache_ outputs and puts them all together in the
same directory structure.

## How can I debug my release mode web app (dart2js)?

By default, the `dart2js` compiler is only enabled in `--release` mode, which
does not include source maps or the original `.dart` files. If you need to
debug an error which only happens in `dart2js`, you will want to change your
debug mode compiler to `dart2js`. You can either do this using the `--define`
command line option:

```text
--define "build_web_compilers|entrypoint=compiler=dart2js"
```

Or by editing your `build.yaml` file:

```yaml
targets:
  $default:
    builders:
      build_web_compilers|entrypoint:
        options:
          compiler: dart2js
```

## How can I include additional sources in my build?

By default, the `build_runner` package only includes some specifically
whitelisted directories, derived from the [package layout conventions](
https://www.dartlang.org/tools/pub/package-layout).

If you have some additional files which you would like to be included as part of
the build, you will need a custom `build.yaml` file. You will want to modify the
`sources` field on the `$default` target:

```yaml
targets:
  $default:
    sources:
      - my_custom_sources/**
      - lib/**
      - web/**
      # Note that it is important to include these in the default target.
      - pubspec.*
```

## Why do Builders need unique outputs?

`build_runner` relies on determining a static build graph before starting a
build - it needs to know every file that may be written and which Builder would
write it. If multiple Builders are configured to (possibly) output the same file
you can:

- Add a `generate_for` configuration for one or both Builders so they do not
  both operate on the same primary input.
- Disable one of the Builders if it is unneeded.
- Contact the author of the Builder and ask that a more unique output extension
  is chosen.
- Contact the author of the Builder and ask that a more unique input extension
  is chose, for example only generating for files that end in `_something.dart`
  rather than all files that end in `.dart`.
  
## How can I use my own development server to serve generated files?

There are 2 options for using a different server during development:

1. Run `build_runner serve web:<port>` and proxy the requests to it from your
other server. This has the benefit of delaying requests while a build is
ongoing so you don't get an inconsistent set of assets.

2. Run `build_runner watch --output web:build` and use the created `build/`
directory to serve files from. This will include a `build/packages` directory
that has these files in it.

## How can I fix `AssetNotFoundException`s for swap files?

Some editors create swap files during saves, and while build_runner uses some
heuristics to try and ignore these, it isn't perfect and we can't hardcode
knowledge about all editors.

One option is to disable this feature in your editor. Another option is you can
explicitly ignore files with a given extension by configuring the `exclude`
option for your targets `sources` in `build.yaml`:

```yaml
targets:
  $default:
    sources:
      exclude:
        # Example that excludes intellij's swap files
        - **/*___jb_tmp___
```

## Why are some logs "(cached)"?

`build_runner` will only run actions that have changes in their inputs. When an
action fails, and a subsequent build has exactly the same inputs for that action
it will not be rerun - the previous error messages, however, will get reprinted
to avoid confusion if a build fails with no printed errors. To force the action
to run again make an edit to any file that is an input to that action, or throw
away all cached values with `pub run build_runner clean` before starting the
next build.

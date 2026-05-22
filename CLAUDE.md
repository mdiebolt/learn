# Project conventions

Always load The Rails Way skill at `~/.config/agents/skills/the-rails-way`

## Routing

Never use `only:` or `except:` to restrict resource actions in `config/routes.rb`. Declare every `resource`/`resources` without action restrictions, even when some actions are unimplemented — Rails will route to a missing controller method as a 404, which is acceptable. This keeps the routing surface uniform and means a new controller action can ship without a routes change.

```ruby
# Yes
resource :preferences
resources :chapters

# No — do not add only:/except:
resource :preferences, only: [:update]
resources :chapters, except: [:destroy]
```

## Comments

Minimize these. Prefer richly-named domain terms. Only add a comment if it explains the "why" of the code in a way that isn’t clear from the method name or invocation flow.

## Views

Don’t wrap tags or erb code into multiple lines.

## Jobs

Pass instances of ActiveRecord objects to jobs rather than ids since Rails knows how to look up the model automatically.

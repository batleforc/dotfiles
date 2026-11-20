# shellcheck shell=bash
# Sourced by ~/.bashrc. Loads the sibling snippets from this file's own
# directory, so the repo can live anywhere.
_dotfiles_default="$(dirname "${BASH_SOURCE[0]}")"
for _snippet in alias functions history init completion; do
    # shellcheck source=/dev/null
    source "$_dotfiles_default/$_snippet.sh"
done
unset _dotfiles_default _snippet

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

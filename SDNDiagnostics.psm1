# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

. "$PSScriptRoot\src\config\app\settings.ps1"

# dot source the private scripts
foreach($item in (Get-ChildItem -Path "$PSScriptRoot\src\modules\private" -Include "*.ps1" -Recurse)){
    . $item.FullName
}

# dot source the public scripts
foreach($item in (Get-ChildItem -Path "$PSScriptRoot\src\modules\public" -Include "*.ps1" -Recurse)){
    . $item.FullName
}

$ErrorActionPreference = 'Continue'
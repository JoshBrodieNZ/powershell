$banner=@"
  ___                     ___ _ _    _
 | _ \_____ __ _____ _ _ / __(_) |__| |__  ___ _ _
 |  _/ _ \ V  V / -_) '_| (_ | | '_ \ '_ \/ _ \ ' \
 |_| \___/\_/\_/\___|_|  \___|_|_.__/_.__/\___/_||_|
"@

Write-Host $banner
if (("APIFuncs" -as [type]) -eq $null)
{
  #Maybe eventually turn this C# into powershell
  #Example EnumWindow code shamelessly pinched from http://www.pinvoke.net/default.aspx/user32.enumchildwindows
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Collections.Generic;
        using System.Text;
        using System.Drawing;
        public class APIFuncs
         {
           [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
           public static extern int GetWindowText(IntPtr hwnd,StringBuilder lpString, int cch);
           [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
           public static extern IntPtr GetForegroundWindow();
           [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
           public static extern Int32 GetWindowThreadProcessId(IntPtr hWnd,out Int32 lpdwProcessId);
           [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
           public static extern Int32 GetWindowTextLength(IntPtr hWnd);
           [DllImport("user32.dll", SetLastError = false)]
           public static extern IntPtr GetDesktopWindow();
           [DllImport("user32.dll")]
           public static extern bool EnableWindow(IntPtr hWnd, bool bEnable);
           [DllImport("user32.dll")]
           public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
           [DllImport("user32.dll")]
           public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
           [DllImport("user32.dll")]
           public static extern bool GetCursorPos(out System.Drawing.Point pt);
           [DllImport("user32.dll")]
           public static extern IntPtr WindowFromPoint(System.Drawing.Point pt);
           [DllImport("user32.dll")]
           public static extern IntPtr GetAncestor(IntPtr hwnd, int flags);
           [DllImport("user32.dll", ExactSpelling=true, CharSet=CharSet.Auto)]
           public static extern IntPtr GetParent(IntPtr hWnd);
           [DllImport("user32.dll", SetLastError = true)]
           public static extern IntPtr GetWindow(IntPtr hWnd, int uCmd);

           [DllImport("user32.dll")]
           [return: MarshalAs(UnmanagedType.Bool)]
           public static extern bool EnumChildWindows(IntPtr window, EnumWindowProc callback, IntPtr i);

           public static List<IntPtr> GetChildWindows(IntPtr parent)
           {
              List<IntPtr> result = new List<IntPtr>();
              GCHandle listHandle = GCHandle.Alloc(result);
              try
              {
                  EnumWindowProc childProc = new EnumWindowProc(EnumWindow);
                  EnumChildWindows(parent, childProc,GCHandle.ToIntPtr(listHandle));
              }
              finally
              {
                  if (listHandle.IsAllocated)
                      listHandle.Free();
              }
              return result;
          }
           private static bool EnumWindow(IntPtr handle, IntPtr pointer)
          {
              GCHandle gch = GCHandle.FromIntPtr(pointer);
              List<IntPtr> list = gch.Target as List<IntPtr>;
              if (list == null)
              {
                  throw new InvalidCastException("GCHandle Target could not be cast as List<IntPtr>");
              }
              list.Add(handle);
              //  You can modify this to check to see if you want to cancel the operation, then return a null here
              return true;
          }
           public delegate bool EnumWindowProc(IntPtr hWnd, IntPtr parameter);
          }
"@ -ReferencedAssemblies System.Drawing
}

function Set-Scope(){
    $topLevelWindowHandle = [int]$windowHandleTextBox.Text
    Write-Host "Scoping to $topLevelWindowHandle"
    UpdateWindowList
}
function Get-WindowName($hwnd) {
    $len = [APIFuncs]::GetWindowTextLength($hwnd)
    if($len -gt 0){
        $sb = New-Object text.stringbuilder -ArgumentList ($len + 1)
        $rtnlen = [APIFuncs]::GetWindowText($hwnd,$sb,$sb.Capacity)
        $sb.tostring()
    }
}
$windowList = New-Object System.Collections.ArrayList
function UpdateWindowList(){
    param(
      [Parameter(Mandatory=$false)][IntPtr]$processScope
    )
    Write-Host "Updating, scoped to $topLevelWindowHandle"
    $windowList.Clear()
    $combobox.Items.Clear()
    foreach ($hWnd in ([APIFuncs]::GetChildWindows($topLevelWindowHandle)))
    {
            #WindowName
            $windowName = (Get-WindowName($hwnd))
            if ($windowName -eq $null)
            {
                $windowName = "null"
            }

            #ProcessID
            $p = [IntPtr]::Zero
            [void][APIFuncs]::GetWindowThreadProcessId($hWnd, [ref]$p)
            if($processScope){
              if(!($processScope -eq $p))
              {
                continue
              }
            }
            #ProcessName
            $processName = (Get-Process -ID $p).ProcessName
            #WindowObject
            $windowObject = New-Object PSObject -Property @{Name=$windowName;Handle=$hWnd;processId=$p;processName=$processName}
            $windowObject | Add-Member ScriptMethod ToString {$this.Name} -force
            [void]$windowList.Add($windowObject)
    }
    $combobox.Items.AddRange($windowList)
}

$windowHandle = 0
$topLevelWindowHandle = [APIFuncs]::GetDesktopWindow()

[Reflection.Assembly]::LoadWithPartialName( "System.Windows.Forms")
[Reflection.Assembly]::LoadWithPartialName( "System.Drawing.Point")
$form = New-Object Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(550,300)

#Initial WindowHandle Restriction
$windowHandleLabel = New-Object System.Windows.Forms.Label
$windowHandleLabel.Text = "Top Level Window"
$windowHandleLabel.Location = New-Object System.Drawing.Point(25,0)
$windowHandleLabel.Size = New-Object System.Drawing.Size(75,25)
$form.Controls.Add($windowHandleLabel)

$windowHandleTextBox = New-Object System.Windows.Forms.TextBox
$windowHandleTextBox.Text = $topLevelWindowHandle;
$windowHandleTextBox.Location = New-Object System.Drawing.Point(100,0)
$windowHandleTextBox.Size = New-Object System.Drawing.Size(100,75)
$windowHandleTextBox_TextChanged =
{
    $topLevelWindowHandle = $windowHandleTextBox.Text
}
$windowHandleTextBox.add_TextChanged($windowHandleTextBox_TextChanged)
$test = 0
$windowHandleTextBox_KeyPress =
{
    param($p1,$p2)
    if (-Not ([System.Char]::IsDigit($p2.KeyChar)))
    {
        $p2.Handled = 1
    }
}
$windowHandleTextBox.add_KeyPress($windowHandleTextBox_KeyPress)
$form.Controls.Add($windowHandleTextBox)

$windowHandleManualSelectButton = New-Object System.Windows.Forms.Button
$windowHandleManualSelectButton.Text = "Manual"
$windowHandleManualSelectButton.Location = New-Object System.Drawing.Point(205,0)
$windowHandleManualSelectButton_Click = {
    Set-Scope
}
$windowHandleManualSelectButton.Add_Click($windowHandleManualSelectButton_Click)
$form.Controls.Add($windowHandleManualSelectButton)

$windowHandleTargetSelectButton = New-Object System.Windows.Forms.Button
$windowHandleTargetSelectButton.Text = "Target"
$windowHandleTargetSelectButton.Location = New-Object System.Drawing.Point(280,0)
$windowHandleTargetSelectButton_Click = {
    Start-Sleep 3
    $pt = New-Object System.Drawing.Point
    [APIFuncs]::GetCursorPos([ref]$pt)
    $hwnd = [APIFuncs]::WindowFromPoint($pt)
    $windowHandleTextBox.Text = $hwnd
    Set-Scope
}
$windowHandleTargetSelectButton.Add_Click($windowHandleTargetSelectButton_Click)
$form.Controls.Add($windowHandleTargetSelectButton)

$windowHandleForegroundSelectButton = New-Object System.Windows.Forms.Button
$windowHandleForegroundSelectButton.Text = "Foreground"
$windowHandleForegroundSelectButton.Location = New-Object System.Drawing.Point(355,0)
$windowHandleForegroundSelectButton_Click = {
    Start-Sleep 3
    $hwnd = [APIFuncs]::GetForegroundWindow()
    $windowHandleTextBox.Text = $hwnd
    Set-Scope
}
$windowHandleForegroundSelectButton.Add_Click($windowHandleForegroundSelectButton_Click)
$form.Controls.Add($windowHandleForegroundSelectButton)

$windowHandleParentSelectButton = New-Object System.Windows.Forms.Button
$windowHandleParentSelectButton.Text = "Parent"
$windowHandleParentSelectButton.Location = New-Object System.Drawing.Point(430,0)
$windowHandleParentSelectButton_Click = {
    $hwnd = [APIFuncs]::GetParent($topLevelWindowHandle)
    $windowHandleTextBox.Text = $hwnd
    Set-Scope
}
$windowHandleParentSelectButton.Add_Click($windowHandleParentSelectButton_Click)
$form.Controls.Add($windowHandleParentSelectButton)

#Dropdown list of window handles
$comboBoxLabel = New-Object System.Windows.Forms.Label
$comboBoxLabel.Text = "Active Window"
$comboBoxLabel.Location = New-Object System.Drawing.Point(25,25)
$comboBoxLabel.Size = New-Object System.Drawing.Size(75,25)
$form.Controls.Add($comboBoxLabel)

$combobox = New-Object System.Windows.Forms.ComboBox
$combobox.Location = New-Object System.Drawing.Point(100,25)
$combobox.Size = New-Object System.Drawing.Size(250,75)

$combobox_SelectedIndexChanged =
{
   $windowHandle = $combobox.selectedItem.Handle
   $windowTitle = $combobox.selectedItem.Name
   $windowPID = $combobox.selectedItem.processId
   $windowProcessName = $combobox.selectedItem.processName

   $windowLabel1.Text = "$windowTitle ($windowHandle)"
   $windowLabel2.Text = "$windowPID - $windowProcessName"
}

$combobox.add_SelectedIndexChanged($combobox_SelectedIndexChanged)
$form.Controls.Add($combobox)

#Label1
$windowLabel1 = New-Object System.Windows.Forms.Label
$windowLabel1.Text = "Window Name Goes Here"
$windowLabel1.Location = New-Object System.Drawing.Point(25,50)
$windowLabel1.Size = New-Object System.Drawing.Size(250,25)
$form.Controls.Add($windowLabel1)

#Label2
$windowLabel2 = New-Object System.Windows.Forms.Label
$windowLabel2.Text = "Window Name Goes Here"
$windowLabel2.Location = New-Object System.Drawing.Point(25,75)
$windowLabel2.Size = New-Object System.Drawing.Size(250,25)
$form.Controls.Add($windowLabel2)

#EnableWindow
$enableButton = New-Object System.Windows.Forms.Button
$enableButton.Text = "Enable"
$enableButton.Location = New-Object System.Drawing.Point(25,100)
$enableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Handle, 1)
}
$enableButton.Add_Click($enableButton_click)
$form.Controls.Add($enableButton)

#DisableWindow
$disableButton = New-Object System.Windows.Forms.Button
$disableButton.Text = "Disable"
$disableButton.Location = New-Object System.Drawing.Point(100,100)
$disableButton_click = {
    [APIFuncs]::EnableWindow($combobox.selectedItem.Handle, 0)
}
$disableButton.Add_Click($disableButton_click)
$form.Controls.Add($disableButton)

#ShowWindow
$showButton = New-Object System.Windows.Forms.Button
$showButton.Text = "Show"
$showButton.Location = New-Object System.Drawing.Point(25,125)
$showButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Handle, 1)
}
$showButton.Add_Click($showButton_click)
$form.Controls.Add($showButton)

#HideWindow
$hideButton = New-Object System.Windows.Forms.Button
$hideButton.Text = "Hide"
$hideButton.Location = New-Object System.Drawing.Point(100,125)
$hideButton_click = {
    [APIFuncs]::ShowWindow($combobox.selectedItem.Handle, 0)
}
$hideButton.Add_Click($hideButton_click)
$form.Controls.Add($hideButton)

#RefreshList
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "Refresh List"
$refreshButton.Location = New-Object System.Drawing.Point(25,150)
$refreshButton_click = {
    UpdateWindowList
}
$refreshButton.Add_Click($refreshButton_click)
$form.Controls.Add($refreshButton)

#Refresh Rescope
#TODO: Consider whether this could probably be implemented more effectively by getting the parent of the selected window
$rescopeButton = New-Object System.Windows.Forms.Button
$rescopeButton.Text = "Rescope"
$rescopeButton.Location = New-Object System.Drawing.Point(100,150)
$rescopeButton_click = {
  UpdateWindowList($combobox.selectedItem.processId)
}
$rescopeButton.Add_Click($rescopeButton_click)
$form.Controls.Add($rescopeButton)

#ShowAll
$showAllButton = New-Object System.Windows.Forms.Button
$showAllButton.Text = "Show All"
$showAllButton.Location = New-Object System.Drawing.Point(25,175)
$showAllButton_click = {
  foreach ($hWnd in ([APIFuncs]::GetChildWindows($topLevelWindowHandle)))
  {
    $p = [IntPtr]::Zero
    [void][APIFuncs]::GetWindowThreadProcessId($hWnd, [ref]$p)
    if ($p -eq $combobox.selectedItem.processId){
      [APIFuncs]::ShowWindow($hWnd, 1)
    }
  }
}
$showAllButton.Add_Click($showAllButton_click)
$form.Controls.Add($showAllButton)

$form.Text = "PowerGibbon"

$form.ShowDialog()

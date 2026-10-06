using System;
using System.Web;
using System.Web.UI;

namespace DBProject
{
    /// <summary>
    /// Health check endpoint for container liveness/readiness probes.
    /// Returns HTTP 200 with JSON status for Kubernetes health checks on EKS.
    /// Accessible at: /Health.aspx
    /// </summary>
    public partial class Health : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            Response.Clear();
            Response.ContentType = "application/json";
            Response.StatusCode = 200;
            Response.Write("{\"status\":\"Healthy\",\"application\":\"DBProject\",\"timestamp\":\"" + DateTime.UtcNow.ToString("o") + "\"}");
            Response.End();
        }
    }
}
